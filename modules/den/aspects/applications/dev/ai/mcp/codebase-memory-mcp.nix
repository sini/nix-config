# The upstream flake, not nixpkgs. nixpkgs tracks release tags and sat on v0.8.1
# (2026-06-12), which predates Nix definition/call extraction — that landed in
# 0849f28c (2026-06-27) and shipped in v0.9.0. Measured on den-hoag: v0.8.1 gives
# 7 Function nodes (all from the one Python file) and 8 CALLS edges; the flake's
# HEAD gives 39 Nix Function nodes and 38 CALLS. The flake exposes exactly one
# output we need, `packages.<system>.default`.
#
# `nixpkgs.follows` dedups the server's build nixpkgs onto ours. `pkgs` here is
# the overlay's build (pkgs/overlays.nix: this flake's package plus one local
# patch), NOT the channel's — see that overlay entry for what the patch fixes.
{
  flake-file.inputs.codebase-memory-mcp = {
    url = "github:DeusData/codebase-memory-mcp";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.applications.dev.ai.mcp.codebase-memory = {
    homeManager =
      {
        inputs',
        pkgs,
        lib,
        ...
      }:
      let
        cbm = inputs'.codebase-memory-mcp.packages.default;
      in
      {
        home.packages = [ cbm ];

        # auto_index defaults to false, which leaves the graph empty until an
        # agent volunteers to index — the augmenter hook is inert against an
        # empty graph, so nothing ever nudges them. Indexing on session start
        # makes the bootstrap deterministic. The setting lives in the server's
        # own sqlite config, hence an idempotent activation step rather than a
        # managed file.
        home.activation.cbmAutoIndex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${cbm}/bin/codebase-memory-mcp config set auto_index true
        '';

        # stdio MCP server: spawned per session by Claude Code, no daemon
        # needed. The per-repo SQLite index lives in ~/.cache and is shared
        # across sessions; incremental git-sync runs inside the server.
        programs.claude-code = {
          mcpServers.codebase-memory = {
            type = "stdio";
            command = "${cbm}/bin/codebase-memory-mcp";
          };

          skills.codebase-memory = ./_skills/codebase-memory;

          settings.hooks =
            let
              sessionReminder = pkgs.writeShellScript "cbm-session-reminder" ''
                cat << 'REMINDER'
                Code Discovery Protocol:
                1. Check coverage before relying on the graph. `get_architecture(project)`
                   lists the languages actually extracted. A language absent from that list
                   has NO symbols in the index no matter how many File/Module nodes exist,
                   and `search_graph` returns 0 for every real identifier in it.
                2. For a COVERED language, prefer codebase-memory-mcp over grep:
                   - search_graph(name_pattern/label/qn_pattern) to find functions/classes/routes
                   - trace_path(function_name, mode=calls|data_flow|cross_service) for call chains
                   - get_code_snippet(qualified_name) for exact symbol source (precise ranges)
                   - query_graph(query) for complex Cypher patterns
                   - get_architecture(aspects) for project structure
                   - search_code(pattern) for text search (graph-augmented grep)
                3. Nix IS covered for definitions and calls. The function-headed-file gap is
                   FIXED (den-hoag measures 2213 Function nodes, 1461 CALLS). Two traps
                   remain, both measured 2026-07-27, and both make a real capability look
                   like an absent one:
                   (a) `get_architecture`'s `languages` FIELD DOES NOT LIST NIX — den-hoag
                       reports only YAML and Python while 2213 Nix functions sit in the same
                       response. Do NOT confirm Nix coverage from that field; confirm it with
                       a known-positive SYMBOL QUERY.
                   (b) CALLS edges MISS ATTRSET-MEDIATED CALLS, which is Nix's dominant
                       cross-module idiom. Measured: `trace_path runPrePass inbound` returns
                       ZERO callers while the real call sits at `lib/default.nix:1097` as
                       `stagedResolution.runPrePass { … }`. Positive control proving the
                       direction works at all: `trace_path fail inbound` returns 23 callers.
                       ⇒ ZERO CALLERS IS NOT EVIDENCE OF DEAD CODE. Cross-check every
                       zero-caller result with Grep before concluding, and absolutely before
                       deleting anything.
                   Strong for STRUCTURE (what exists, what a function calls, clustering,
                   fan-in). NOT trustworthy alone for REACHABILITY or liveness. Nix bindings
                   still yield no Variable nodes, and only a literal `import ./path` becomes
                   an edge — flake inputs are invisible, so there are no cross-repo edges.
                4. For Nix symbols prefer the nix LSP (nil, registered for .nix):
                   documentSymbol for a file outline, hover, and file-local goToDefinition /
                   findReferences. nil is single-file — workspace/symbol and call hierarchy
                   are unsupported, and it cannot resolve a member across an import
                   (`prelude.genAttrs` never resolves, however `prelude` is bound).
                5. Use Grep/Glob/Read freely for text, configs, non-code files, and
                   always Read a file before editing it.
                6. If a project is not indexed yet, run index_repository FIRST — and never
                   pass mode: only the default (full) walks the whole tree. `fast` and
                   `moderate` apply a NAME-based directory skip list that includes `gen`,
                   `media`, `docs`, `examples`, `scripts`, `tools`, `bin`, `build`,
                   `external`, `integration` and more. Those are ordinary source directory
                   names here, and a skipped directory is silently absent from the graph —
                   indistinguishable from code that does not exist.
                REMINDER
              '';

              # The context is prose, so both escapings are derived and never
              # hand-written: `toJSON` owns the quoting inside the payload and
              # `escapeShellArg` owns the quoting around it. A hand-quoted payload
              # only has to contain one apostrophe (`get_architecture's`) to close
              # the shell string and leave the remainder as bare tokens.
              subagentContext = "Code discovery: prefer codebase-memory-mcp tools (search_graph, trace_path, get_code_snippet, query_graph, search_code) over grep for languages the index covers. Nix IS covered for defs and calls (the function-headed-file gap is fixed). TWO TRAPS: (a) get_architecture's languages field does NOT list Nix even when thousands of Nix functions are indexed - confirm coverage with a known-positive symbol query, never that field; (b) CALLS edges MISS attrset-mediated calls (stagedResolution.runPrePass), so ZERO CALLERS IS NOT EVIDENCE OF DEAD CODE - cross-check with Grep before concluding or deleting. Strong for structure, not trustworthy alone for reachability. Nix still yields no Variable nodes and no cross-repo edges. The nix LSP (documentSymbol, hover, file-local goToDefinition) complements it. Never pass mode to index_repository - the default (full) walks everything, while fast/moderate silently skip directories named gen, media, docs, examples, scripts, tools, bin, build. Use Grep/Glob/Read for text, configs, and non-code files.";

              subagentReminder = pkgs.writeShellScript "cbm-subagent-reminder" ''
                printf '%s\n' ${
                  lib.escapeShellArg (
                    builtins.toJSON {
                      hookSpecificOutput = {
                        hookEventName = "SubagentStart";
                        additionalContext = subagentContext;
                      };
                    }
                  )
                }
              '';

              hookOf = command: [
                {
                  hooks = [
                    {
                      type = "command";
                      inherit command;
                    }
                  ];
                }
              ];
            in
            {
              PreToolUse = [
                {
                  matcher = "Grep|Glob";
                  hooks = [
                    {
                      type = "command";
                      command = pkgs.writeShellScript "cbm-search-augmenter" ''
                        ${cbm}/bin/codebase-memory-mcp hook-augment 2>/dev/null
                        exit 0
                      '';
                    }
                  ];
                }
              ];
              SessionStart = hookOf "${sessionReminder}";
              SubagentStart = hookOf "${subagentReminder}";
            };
        };

        programs.git.ignores = [
          "/AGENTS.md"
          ".cbmignore"
        ];
      };
  };
}

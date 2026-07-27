# The upstream flake, not nixpkgs. nixpkgs tracks release tags and sat on v0.8.1
# (2026-06-12), which predates Nix definition/call extraction — that landed in
# 0849f28c (2026-06-27) and shipped in v0.9.0. Measured on den-hoag: v0.8.1 gives
# 7 Function nodes (all from the one Python file) and 8 CALLS edges; the flake's
# HEAD gives 39 Nix Function nodes and 38 CALLS. The flake exposes exactly one
# output we need, `packages.<system>.default`.
#
# `nixpkgs.follows` dedups the server's build nixpkgs onto ours.
{
  flake-file.inputs.codebase-memory-mcp = {
    url = "github:DeusData/codebase-memory-mcp";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.apps.dev.ai.mcp.codebase-memory = {
    homeManager =
      {
        pkgs,
        lib,
        inputs',
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
                3. Nix is PARTIALLY covered. Definitions are extracted only from files whose
                   ROOT expression is a `let` or an attrset. A file headed by a function
                   pattern (`{ pkgs, ... }:` — most module and lib files) yields NO Function
                   nodes at all. Nix bindings yield no Variable nodes either, and only a
                   literal `import ./path` becomes an edge: flake inputs are invisible, so
                   there are no cross-repo edges. Treat a Nix graph miss as INCONCLUSIVE,
                   never as absence — confirm with the LSP or Grep before concluding.
                4. For Nix symbols prefer the nix LSP (nil, registered for .nix):
                   documentSymbol for a file outline, hover, and file-local goToDefinition /
                   findReferences. nil is single-file — workspace/symbol and call hierarchy
                   are unsupported, and it cannot resolve a member across an import
                   (`prelude.genAttrs` never resolves, however `prelude` is bound).
                5. Use Grep/Glob/Read freely for text, configs, non-code files, and
                   always Read a file before editing it.
                6. If a project is not indexed yet, run index_repository FIRST.
                REMINDER
              '';

              subagentReminder = pkgs.writeShellScript "cbm-subagent-reminder" ''
                printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"Code discovery: for languages the index actually covers (check get_architecture), prefer codebase-memory-mcp tools (search_graph, trace_path, get_code_snippet, query_graph, search_code) over grep. Nix is PARTIALLY covered - defs are extracted only from files whose root is a let or an attrset, so a file headed by a function pattern ({ pkgs, ... }:) yields none; a Nix graph miss is inconclusive, not absence. For Nix symbols use the nix LSP (documentSymbol, hover, file-local goToDefinition) and Grep. Use Grep/Glob/Read for text, configs, and non-code files."}}'
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

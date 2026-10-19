# gen-agents: the four recurring subagent roles of the gen/den architecture effort,
# declared once instead of re-typed into every dispatch prompt.
#
# ★ WHY THIS EXISTS. Orchestration in this project dispatches fresh-context agents, and
# every dispatch was carrying the same ~25-line block of instrument facts — zsh is not
# bash, `grep -c` counts lines, `0/0` is a false pass, an absence needs a live control.
# That block is the part most likely to be dropped under pressure, and dropping it
# produces exactly the failures it warns about (measured: an empty control that read as
# a pass; coordinates read at a working clone instead of the locked rev). Declared here,
# it cannot be forgotten; a dispatch prompt then carries only what is task-specific.
#
# ★ TOOL RESTRICTION IS THE POINT WHERE IT ACTUALLY BINDS, and it does not bind
# everywhere. `gen-gate` and `gen-scout` get no Edit tool: a reviewer without the
# revising tools cannot quietly repair the artefact it is judging.
# Both keep Write and Bash, so this withholds revision, not writing: withholding Write
# never prevented writing, because Bash heredocs write just as well, and in 10 of 29
# sampled transcripts they did, invisibly. Declared writing beats unobservable writing.
#
# MCP tools are listed by name, never as `mcp__<server>__*`: a wildcard would hand the
# reviewers serena's editors and every agent the bank- and index-deleting tools. A tool
# a server adds later is absent until listed here — add it deliberately.
#
# Frontmatter is Claude Code's own schema — name / description / tools / model. Note that
# opencode-style keys (`mode`, `temperature`, nested tools+permission maps) are silently
# ignored here and are deliberately absent.
#
# ★ THE SHARED HALF IS SINGLE-SOURCED, and that is a correctness property rather than
# tidiness. Measured 2026-08-27: 103 lines were identical across all four role files,
# 57% of their total, so every fix cost four edits — and two drifts were introduced in
# a single editing round, including one where a rule was copied without the measurement
# that justified it. Each role is now `head + shared-measurement + role body +
# shared-protocol`, composed below, so the shared text cannot diverge by construction.
{
  den.aspects.applications.dev.ai.skills.gen-agents = {
    agent-extensions =
      { lib, pkgs, ... }:
      let
        d = ./assets/gen-agents;
        shared = builtins.readFile "${d}/_shared-measurement.md";
        protocol = builtins.readFile "${d}/_shared-protocol.md";

        mcp = server: map (t: "mcp__plugin_hm_${server}__${t}");
        # The set gen-* transcripts actually called (6 of 53 granted, 251 transcripts,
        # 2026-10-19 audit), plus the codebase-memory readers. A tool comes back only
        # with a named role use. Read, recall and bank-append only: no bank
        # delete/clear/update, no directive writes, no index deletion, and no `reflect`
        # (LLM synthesis measured to invert a fact; its schema takes no `types`,
        # den-hoag-mgnv3). No serena editors: Edit carries every edit.
        mcpCommon =
          mcp "hindsight" [
            "recall"
            "sync_retain"
            "get_memory"
            "list_memories"
            "invalidate_memory"
          ]
          ++ mcp "codebase-memory" [
            "search_graph"
            "search_code"
            "get_code_snippet"
            "trace_path"
            "query_graph"
            "index_status"
          ];
        base = [
          "Read"
          "Grep"
          "Glob"
          "Bash"
          "Write"
          "SendMessage"
        ];
        tools = {
          scout = base ++ mcpCommon;
          gate = base ++ mcpCommon;
          spec = base ++ [ "Edit" ] ++ mcpCommon;
          build = base ++ [ "Edit" ] ++ mcpCommon;
        };
        # Pinned so a dispatch without a model never inherits the orchestrator's; a
        # per-dispatch `model` still overrides it.
        models = {
          scout = "opus";
          gate = "opus";
          spec = "opus";
          build = "opus";
        };

        # Order matters: head, then the shared measurement block, then the role body,
        # then the shared protocol. Diff the rendered agents before and after any change
        # here (assets/gen-agents/README.md, "Checking a change").
        mkAgent =
          role:
          pkgs.writeText "gen-${role}.md" (
            builtins.replaceStrings
              [ "@TOOLS@" "@MODEL@" ]
              [
                "[${lib.concatStringsSep ", " tools.${role}}]"
                models.${role}
              ]
              (builtins.readFile "${d}/_${role}-head.md")
            + "\n"
            + shared
            + "\n"
            + builtins.readFile "${d}/_${role}-body.md"
            + "\n"
            + protocol
          );
      in
      {
        type = "skill";
        agents = {
          gen-scout = mkAgent "scout";
          gen-gate = mkAgent "gate";
          gen-spec = mkAgent "spec";
          gen-build = mkAgent "build";
        };
      };
  };
}

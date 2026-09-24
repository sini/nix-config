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
# everywhere. `gen-gate` and `gen-scout` get no Edit and no serena editing tool: a
# reviewer without the revising tools cannot quietly repair the artefact it is judging.
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
        # Read, recall and bank-append only: no bank delete/clear/update, no directive
        # writes (law is the owner's to write), no index deletion.
        mcpCommon =
          mcp "hindsight" [
            "recall"
            "reflect"
            "sync_retain"
            "retain"
            "get_memory"
            "list_memories"
            "invalidate_memory"
            "get_operation"
            "list_tags"
            "list_documents"
            "get_document"
            "list_directives"
            "list_mental_models"
            "get_mental_model"
            "search_knowledge_base"
            "get_knowledge_base_tree"
            "get_knowledge_page"
          ]
          ++ mcp "codebase-memory" [
            "list_projects"
            "index_status"
            "index_repository"
            "check_index_coverage"
            "get_architecture"
            "get_graph_schema"
            "get_file_outline"
            "get_code_snippet"
            "search_graph"
            "search_code"
            "query_graph"
            "trace_path"
            "detect_changes"
            "compare_graphs"
          ]
          ++ mcp "serena" [
            "initial_instructions"
            "find_symbol"
            "find_declaration"
            "find_implementations"
            "find_referencing_symbols"
            "get_symbols_overview"
            "get_diagnostics_for_file"
            "list_memories"
            "read_memory"
          ]
          ++ mcp "graphify" [
            "graph_stats"
            "god_nodes"
            "get_node"
            "get_neighbors"
            "get_community"
            "shortest_path"
            "query_graph"
            "list_prs"
            "get_pr_impact"
            "triage_prs"
          ]
          ++ mcp "codegraph" [ "codegraph_explore" ]
          ++ mcp "headroom" [
            "headroom_compress"
            "headroom_retrieve"
            "headroom_stats"
          ];
        serenaEdit = mcp "serena" [
          "replace_content"
          "replace_in_files"
          "replace_symbol_body"
          "rename_symbol"
          "insert_before_symbol"
          "insert_after_symbol"
          "safe_delete_symbol"
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
          spec = base ++ [ "Edit" ] ++ mcpCommon ++ serenaEdit;
          build = base ++ [ "Edit" ] ++ mcpCommon ++ serenaEdit;
        };

        # Order matters: head, then the shared measurement block, then the role body,
        # then the shared protocol. Diff the rendered agents before and after any change
        # here (assets/gen-agents/README.md, "Checking a change").
        mkAgent =
          role:
          pkgs.writeText "gen-${role}.md" (
            builtins.replaceStrings [ "@TOOLS@" ] [ "[${lib.concatStringsSep ", " tools.${role}}]" ] (
              builtins.readFile "${d}/_${role}-head.md"
            )
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

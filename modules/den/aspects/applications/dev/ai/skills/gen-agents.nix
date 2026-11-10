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

        # ★ THE CODEX VARIANT. agents/codex.nix turns these into codex role TOMLs, and three
        # passages above are untrue there: delivery (codex returns a child's final message to
        # its parent through wait_agent, and has no SendMessage or SubagentHandback), recall
        # (codex injects no den-law block at subagent start, and names MCP tools by server,
        # mcp__hindsight__recall), and tool restriction (a codex role cannot withhold tools, so
        # gate and scout DO have editing tools; the rule is behavioural there). Each swap must
        # match exactly once, or the build fails, so a source edit cannot leave a stale passage.
        swapOnce =
          role: text: pairs:
          lib.foldl' (
            acc:
            { from, to }:
            let
              n = lib.length (lib.splitString from acc) - 1;
            in
            if n != 1 then
              throw "gen-agents codex variant (${role}): expected the passage once, found it ${toString n} times: ${lib.substring 0 60 from}"
            else
              builtins.replaceStrings [ from ] [ to ] acc
          ) text pairs;
        noEditFor = {
          scout = [
            {
              from = "has no Edit tool\n  and does not revise the artefact under measurement";
              to = "must not edit\n  (codex cannot withhold editing tools from a role, so this is a rule, not a\n  restriction) and does not revise the artefact under measurement";
            }
            {
              from = "- **Name which one in your `SendMessage`** — a routing recommendation reaches the\n  orchestrator through that message or through nothing at all.";
              to = "- **Name which one in your final message** — a routing recommendation reaches the\n  orchestrator through that message or through nothing at all.";
            }
          ];
          gate = [
            {
              from = "Has no Edit or\n  editing tool, so it does not revise the artefact it judges.";
              to = "Must not edit\n  the artefact it judges (codex cannot withhold editing tools from a role, so\n  this is a rule, not a restriction).";
            }
            {
              from = "you have no Edit tool, and Bash is not a\nsubstitute for one.";
              to = "codex gives you editing tools anyway, and\nusing them, or Bash, on the artefact is forbidden; you write only your report.";
            }
          ];
          spec = [ ];
          build = [ ];
        };
        protocolForCodex = [
          {
            from = "★ **As a teammate (the usual dispatch) your final text reaches nobody: deliver\nwith `SendMessage` to the orchestrator.** If your tools include\n`SubagentHandback`, deliver through it instead and do not also `SendMessage`.\nEither way, write the file too: the file is the artefact, the message the\nnotification.";
            to = "★ **Your final message is the delivery.** Codex returns a subagent's final\nmessage to its parent (the parent collects it with `wait_agent`). End with the\ndeliverable, and do not also message the parent unless it asked you to. Write\nthe file too: the file is the artefact, the final message the notification.";
          }
          {
            from = "Send, briefly:";
            to = "End with, briefly:";
          }
          {
            from = "If you wrote nothing, or an attempt failed, send that.";
            to = "If you wrote nothing, or an attempt failed, say that.";
          }
          {
            from = "You are already a subagent; do not dispatch your own. If you cannot finish, send\none of these and stop rather than improvising around the gap:";
            to = "You are already a subagent; do not dispatch your own. If you cannot finish, end\nwith one of these and stop rather than improvising around the gap:";
          }
          {
            from = "Your role's standing law and tool traps were injected at start (the den-law recall\nblock). If that block says the recall FAILED, run `mcp__plugin_hm_hindsight__recall`\nyourself before measuring (if it is deferred, load it with `tool_search_tool_regex`,\npattern `hindsight__recall`).";
            to = "Your role's standing law and tool traps were injected at start (the den-law recall\nblock). If that block is absent or says the recall FAILED, run the hindsight\nserver's `recall` tool yourself (listed as `mcp__hindsight__recall`) before\nmeasuring. If your tool list has no hindsight tools, or the call fails or times out,\nthe bank is unreachable from this host: report `recall: unavailable` with the\nerror, and never read that as an empty bank.";
          }
          {
            from = "store it with `mcp__plugin_hm_hindsight__sync_retain` and confirm it\nwith `get_memory`";
            to = "store it with the hindsight server's `sync_retain` (`mcp__hindsight__sync_retain`)\nand confirm it with `get_memory`";
          }
        ];
        mkCodexAgent =
          role:
          pkgs.writeText "gen-${role}.codex.md" (
            swapOnce role (builtins.readFile (mkAgent role)) (noEditFor.${role} ++ protocolForCodex)
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
        codexAgents = {
          gen-scout = mkCodexAgent "scout";
          gen-gate = mkCodexAgent "gate";
          gen-spec = mkCodexAgent "spec";
          gen-build = mkCodexAgent "build";
        };
      };
  };
}

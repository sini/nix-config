{
  den.aspects.apps.dev.ai.mcp.codebase-memory = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = with pkgs; [
          codebase-memory-mcp
        ];

        # auto_index defaults to false, which leaves the graph empty until an
        # agent volunteers to index — the augmenter hook is inert against an
        # empty graph, so nothing ever nudges them. Indexing on session start
        # makes the bootstrap deterministic. The setting lives in the server's
        # own sqlite config, hence an idempotent activation step rather than a
        # managed file.
        home.activation.cbmAutoIndex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${pkgs.codebase-memory-mcp}/bin/codebase-memory-mcp config set auto_index true
        '';

        # stdio MCP server: spawned per session by Claude Code, no daemon
        # needed. The per-repo SQLite index lives in ~/.cache and is shared
        # across sessions; incremental git-sync runs inside the server.
        programs.claude-code = {
          mcpServers.codebase-memory = {
            type = "stdio";
            command = "${pkgs.codebase-memory-mcp}/bin/codebase-memory-mcp";
          };

          skills.codebase-memory = ./_skills/codebase-memory;

          settings.hooks =
            let
              sessionReminder = pkgs.writeShellScript "cbm-session-reminder" ''
                cat << 'REMINDER'
                CRITICAL - Code Discovery Protocol:
                1. ALWAYS use codebase-memory-mcp tools FIRST for ANY code exploration:
                   - search_graph(name_pattern/label/qn_pattern) to find functions/classes/routes
                   - trace_path(function_name, mode=calls|data_flow|cross_service) for call chains
                   - get_code_snippet(qualified_name) for exact symbol source (precise ranges)
                   - query_graph(query) for complex Cypher patterns
                   - get_architecture(aspects) for project structure
                   - search_code(pattern) for text search (graph-augmented grep)
                2. Use Grep/Glob/Read freely for text, configs, non-code files, and
                   always Read a file before editing it.
                3. If a project is not indexed yet, run index_repository FIRST.
                REMINDER
              '';

              subagentReminder = pkgs.writeShellScript "cbm-subagent-reminder" ''
                printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"Code discovery: prefer codebase-memory-mcp tools (search_graph, trace_path, get_code_snippet, query_graph, get_architecture, search_code) over grep/file-read for navigating code. Use Grep/Glob/Read for text, configs, and non-code files."}}'
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
                        ${pkgs.codebase-memory-mcp}/bin/codebase-memory-mcp hook-augment 2>/dev/null
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

# OpenCode (https://opencode.ai):
# Terminal AI coding agent with rich Home Manager configuration, MCP server routing,
# local inference patterning, and declarative skill/subagent deployment.
{ ... }:
{
  den.aspects.applications.dev.ai.agents.opencode = {
    homeManager =
      {
        config,
        inputs',
        lib,
        ninfer-endpoints ? [ ],
        agent-extensions ? { },
        ...
      }:
      let
        # ponytail: first endpoint wins — key by hostname if a second inference host appears.
        ninfer = if ninfer-endpoints == [ ] then null else builtins.head ninfer-endpoints;

        # Extract collected extensions
        collectedSkills = agent-extensions.skills or { };
        collectedAgents = agent-extensions.agents or { };
        collectedMcp = agent-extensions.mcpServers or { };

        # Unwrap flake input attrsets to pure Nix store paths
        resolveSrc = src: src.outPath or src;

        # Filter invalid MCP attributes
        formatMcpForOpencode =
          mcpMap:
          lib.mapAttrs (
            _: server:
            lib.filterAttrs (_: v: v != [ ] && v != { }) {
              inherit (server) command args env;
            }
          ) mcpMap;

        opencodeConfig = {
          "$schema" = "https://opencode.ai/config.json";
          provider = {
            name = if ninfer != null then "NInfer" else "Ollama";
            baseUrl =
              if ninfer != null then
                "http://${ninfer.ip}:${toString ninfer.port}/v1"
              else
                "http://10.9.2.2:11434/v1";
            model = if ninfer != null then ninfer.modelId else "qwen3.8:27b";
          };
          permission = {
            bash = "allow";
            edit = "allow";
            read = "allow";
            web_fetch = "allow";
          };
          mcp = formatMcpForOpencode collectedMcp;
        };

        tuiConfig = {
          "$schema" = "https://opencode.ai/tui.json";
          theme = "dark";
        };

        # Convert collected skills to Home Manager file definitions
        skillFiles = lib.mapAttrs' (
          name: src:
          lib.nameValuePair ".config/opencode/skills/${name}" {
            source = resolveSrc src;
          }
        ) collectedSkills;

        # Convert collected subagents to Home Manager file definitions
        agentFiles = lib.mapAttrs' (
          name: src:
          lib.nameValuePair ".config/opencode/agent/${name}.md" {
            source = resolveSrc src;
          }
        ) collectedAgents;
      in
      {
        home.packages = [
          inputs'.llm-agents.packages.opencode
        ];

        programs.git.ignores = [
          "/.opencode/"
        ];

        # Deploy config files, skills, and subagents in single merged home.file block
        home.file =
          {
            ".config/opencode/opencode.json".text = builtins.toJSON opencodeConfig;
            ".config/opencode/tui.json".text = builtins.toJSON tuiConfig;
          }
          // skillFiles
          // agentFiles;
      };

    persistHome = {
      directories = [
        ".config/opencode"
      ];
    };
  };
}

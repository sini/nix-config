# Gemini / Antigravity agent harness and CLI tooling.
# Provides antigravity-cli (agy), gemini-cli, and openskills from numtide/llm-agents,
# manages global ~/.gemini customization tree, MCP server registry, and persistence.
{
  den.aspects.applications.dev.ai.agents.gemini = {
    homeManager =
      {
        agent-extensions,
        config,
        inputs',
        lib,
        pkgs,
        ...
      }:
      let
        extensionsList = lib.flatten agent-extensions;

        # 1. Skills collection
        allSkillSources = lib.foldl' (
          acc: e:
          if (e ? skills) then
            acc // (lib.mapAttrs (_: src: src.outPath or src) e.skills)
          else
            acc
        ) { } extensionsList;

        skillFiles = lib.mapAttrs' (
          name: source:
          lib.nameValuePair ".gemini/config/skills/${name}" {
            inherit source;
          }
        ) allSkillSources;

        # 2. Subagents collection
        allAgentSources = lib.foldl' (
          acc: e: if (e ? agents) then acc // e.agents else acc
        ) { } extensionsList;

        agentFiles = lib.mapAttrs' (
          name: source:
          lib.nameValuePair ".gemini/config/agents/${name}.md" {
            inherit source;
          }
        ) allAgentSources;

        # 3. Slash commands collection
        allCommandSources = lib.foldl' (
          acc: e: if (e ? commands) then acc // e.commands else acc
        ) { } extensionsList;

        commandFiles = lib.mapAttrs' (
          name: source:
          lib.nameValuePair ".gemini/config/commands/${name}.md" {
            inherit source;
          }
        ) allCommandSources;

        # 4. stdio MCP servers
        mcpExts = lib.filter (e: e.type or "" == "mcp") extensionsList;
        allMcpServers = lib.foldl' (acc: e: acc // (e.mcpServers or { })) { } mcpExts;

        mcpConfig = {
          mcpServers = lib.mapAttrs (
            _name: server:
            lib.filterAttrs (_: v: v != [ ] && v != { }) {
              command = server.command;
              args = server.args or [ ];
              env = server.env or { };
            }
          ) allMcpServers;
        };
        mcpJson = (pkgs.formats.json { }).generate "antigravity-mcp-config.json" mcpConfig;
      in
      {
        home.packages = [
          inputs'.llm-agents.packages.antigravity-cli
          inputs'.llm-agents.packages.gemini-cli
          inputs'.llm-agents.packages.openskills
        ];

        home.sessionVariables = {
          GEMINI_CONFIG_DIR = "${config.home.homeDirectory}/.gemini/config";
          ANTIGRAVITY_CONFIG_DIR = "${config.home.homeDirectory}/.gemini/config";
        };

        programs.git.ignores = [
          "/.gemini/"
        ];

        # Base customization root layout + dynamic skills/agents/commands collection
        home.file =
          skillFiles
          // agentFiles
          // commandFiles
          // {
            ".gemini/config/skills/.keep".text = "";
            ".gemini/config/rules/.keep".text = "";

            # Declarative gemini-cli default configuration
            ".config/gemini/config.yaml".text = builtins.toJSON {
              model = "gemini-2.5-pro";
              temperature = 0.2;
            };

            # Dynamic MCP server config linking across CLI & IDE discovery paths:
            ".gemini/config/mcp_config.json".source = mcpJson;
            ".gemini/antigravity/mcp_config.json".source = mcpJson;
            ".gemini/settings.json".source = mcpJson;
            ".config/gemini/settings.json".source = mcpJson;
            ".config/antigravity/mcp_config.json".source = mcpJson;
          };
      };

    persistHome = {
      directories = [
        ".gemini/config"
        ".gemini/antigravity-ide"
        ".gemini/brain"
      ];
    };

    cacheHome = {
      directories = [
        ".gemini/cache"
      ];
    };
  };
}

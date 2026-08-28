# Gemini / Antigravity agent harness and CLI tooling.
# Provides antigravity-cli (agy), gemini-cli, and openskills from numtide/llm-agents,
# manages global ~/.gemini customization tree, MCP server registry, and persistence.
{
  den.aspects.applications.dev.ai.agents.antigravity-cli = {
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
      in
      {
        home.packages = [
          inputs'.llm-agents.packages.gemini-cli
          inputs'.llm-agents.packages.openskills
        ];

        programs.antigravity-cli = {
          enable = true;
          package = inputs'.llm-agents.packages.antigravity-cli;
          skills = allSkillSources;
          mcpServers = allMcpServers;
          commands = allCommandSources;
          # Omit settings ({}) so Home Manager does not generate a read-only settings.json
          # symlink that blocks runtime OAuth token writes (see nix-community/home-manager#8654).
        };

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
          };
      };

    persistHome = {
      directories = [
        ".gemini"
        ".config/antigravity-cli"
        ".config/gemini"
      ];
    };
  };
}

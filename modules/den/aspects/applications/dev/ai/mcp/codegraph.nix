# codegraph (github:colbymchenry/codegraph): Semantic code intelligence and
# fast 100% local code graph for AI coding agents. Package comes from
# llm-agents.nix.
{
  den.aspects.applications.dev.ai.mcp.codegraph = {
    agent-extensions =
      { inputs', ... }:
      {
        type = "mcp";
        mcpServers = {
          codegraph = {
            command = "${inputs'.llm-agents.packages.codegraph}/bin/codegraph";
            args = [
              "serve"
              "--mcp"
            ];
          };
        };
      };

    homeManager =
      { inputs', ... }:
      let
        codegraph = inputs'.llm-agents.packages.codegraph;
      in
      {
        home.packages = [ codegraph ];

        programs.claude-code = {
          settings.permissions.allow = [
            "Bash(codegraph *)"
          ];
        };

        programs.git.ignores = [
          ".codegraph"
        ];
      };
  };
}

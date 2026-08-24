# codegraph (github:colbymchenry/codegraph): Semantic code intelligence and
# fast 100% local code graph for AI coding agents. Package comes from
# llm-agents.nix.
{
  den.aspects.applications.dev.ai.codegraph = {
    homeManager =
      { inputs', ... }:
      let
        codegraph = inputs'.llm-agents.packages.codegraph;
      in
      {
        home.packages = [ codegraph ];

        programs.claude-code = {
          mcpServers.codegraph = {
            type = "stdio";
            command = "${codegraph}/bin/codegraph";
          };

          settings.permissions.allow = [
            "Bash(codegraph *)"
          ];
        };

        programs.git.ignores = [
          "/.codegraph/"
        ];
      };
  };
}

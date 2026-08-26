# calldiff: Static & dynamic call-graph diffing tool and reachability analyzer.
{
  den.aspects.applications.dev.ai.tools.calldiff = {
    agent-extensions = {
      type = "skill";
      skills = {
        calldiff = ../skills/assets/calldiff;
      };
    };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          (pkgs.writeShellApplication {
            name = "calldiff";
            runtimeInputs = [
              pkgs.nodejs
            ];
            text = ''
              exec npx --yes calldiff "$@"
            '';
          })
        ];
      };
  };
}

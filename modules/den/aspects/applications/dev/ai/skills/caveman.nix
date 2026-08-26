# caveman (github:JuliusBrussee/caveman): Concise, high-density token-minimizing
# prompt skill for Claude Code.
{ inputs, ... }:
{
  flake-file.inputs.caveman = {
    url = "github:JuliusBrussee/caveman";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.caveman = {
    homeManager =
      { ... }:
      {
        programs.claude-code = {
          marketplaces.caveman = inputs.caveman;
          settings.enabledPlugins."caveman@caveman" = true;
        };
      };
  };
}

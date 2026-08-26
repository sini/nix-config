# caveman (github:JuliusBrussee/caveman): Concise, high-density token-minimizing
# prompt skill for AI coding agents.
{ inputs, ... }:
{
  flake-file.inputs.caveman = {
    url = "github:JuliusBrussee/caveman";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.caveman = {
    agent-extensions = {
      type = "plugin";
      marketplace = {
        name = "caveman";
        src = inputs.caveman;
        pluginId = "caveman@caveman";
      };
      skills = {
        caveman = inputs.caveman;
      };
    };
  };
}

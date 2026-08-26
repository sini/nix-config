# mattpocock-skills (github:mattpocock/skills): TypeScript/Web development skills.
{ inputs, ... }:
{
  flake-file.inputs.mattpocock-skills = {
    url = "github:mattpocock/skills";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.mattpocock = {
    agent-extensions = {
      type = "plugin";
      marketplace = {
        name = "mattpocock";
        src = inputs.mattpocock-skills;
        pluginId = "mattpocock-skills@mattpocock";
      };
      skills = {
        mattpocock = inputs.mattpocock-skills;
      };
    };
  };
}

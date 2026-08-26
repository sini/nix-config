# superpowers (github:pcvelz/superpowers): Workflow skills and extended capabilities.
{ inputs, ... }:
{
  flake-file.inputs.superpowers-extended-cc = {
    url = "github:pcvelz/superpowers";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.superpowers = {
    agent-extensions = {
      type = "plugin";
      marketplace = {
        name = "superpowers-extended-cc-marketplace";
        src = inputs.superpowers-extended-cc;
        pluginId = "superpowers-extended-cc@superpowers-extended-cc-marketplace";
      };
      skills = {
        superpowers = inputs.superpowers-extended-cc;
      };
    };
  };
}

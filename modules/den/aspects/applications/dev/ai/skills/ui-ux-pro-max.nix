# ui-ux-pro-max (github:nextlevelbuilder/ui-ux-pro-max-skill): UI/UX design intelligence skill.
{ inputs, ... }:
{
  flake-file.inputs.ui-ux-pro-max-skill = {
    url = "github:nextlevelbuilder/ui-ux-pro-max-skill";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.ui-ux-pro-max = {
    agent-extensions = {
      type = "plugin";
      marketplace = {
        name = "ui-ux-pro-max-skill";
        src = inputs.ui-ux-pro-max-skill;
        pluginId = "ui-ux-pro-max@ui-ux-pro-max-skill";
      };
      skills = {
        ui-ux-pro-max = inputs.ui-ux-pro-max-skill;
      };
    };
  };
}

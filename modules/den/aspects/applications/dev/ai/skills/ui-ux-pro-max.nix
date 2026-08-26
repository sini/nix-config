# ui-ux-pro-max (github:nextlevelbuilder/ui-ux-pro-max-skill): Design intelligence
# skill with 84 styles, 192 palettes, 74 font pairings, and stack guidelines.
{ inputs, ... }:
{
  flake-file.inputs.ui-ux-pro-max-skill = {
    url = "github:nextlevelbuilder/ui-ux-pro-max-skill";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.ui-ux-pro-max = {
    homeManager =
      { ... }:
      {
        programs.claude-code = {
          marketplaces.ui-ux-pro-max-skill = inputs.ui-ux-pro-max-skill;
          settings.enabledPlugins."ui-ux-pro-max@ui-ux-pro-max-skill" = true;
        };
      };
  };
}

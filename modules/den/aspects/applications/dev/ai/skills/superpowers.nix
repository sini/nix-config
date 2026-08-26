# superpowers (github:pcvelz/superpowers): Workflow skills and extended capabilities
# for Claude Code.
{ inputs, ... }:
{
  flake-file.inputs.superpowers-extended-cc = {
    url = "github:pcvelz/superpowers";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.superpowers = {
    homeManager =
      { ... }:
      {
        programs.claude-code = {
          marketplaces.superpowers-extended-cc-marketplace = inputs.superpowers-extended-cc;
          settings.enabledPlugins."superpowers-extended-cc@superpowers-extended-cc-marketplace" = true;
        };
      };
  };
}

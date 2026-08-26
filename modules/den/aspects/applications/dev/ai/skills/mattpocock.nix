# mattpocock-skills (github:mattpocock/skills): TypeScript/Web development skills
# for Claude Code.
{ inputs, ... }:
{
  flake-file.inputs.mattpocock-skills = {
    url = "github:mattpocock/skills";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.mattpocock = {
    homeManager =
      { ... }:
      {
        programs.claude-code = {
          marketplaces.mattpocock = inputs.mattpocock-skills;
          settings.enabledPlugins."mattpocock-skills@mattpocock" = true;
        };
      };
  };
}

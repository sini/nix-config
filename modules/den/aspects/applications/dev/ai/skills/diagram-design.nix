# diagram-design (github:cathrynlavery/diagram-design): Editorial diagrams your
# designer won't hate — 39 visual diagram types for Claude Code, Codex, and Pi.
{ inputs, ... }:
{
  flake-file.inputs.diagram-design = {
    url = "github:cathrynlavery/diagram-design";
    flake = false;
  };

  den.aspects.applications.dev.ai.diagram-design = {
    homeManager =
      { ... }:
      {
        programs.claude-code = {
          marketplaces.diagram-design = inputs.diagram-design;
          settings.enabledPlugins."diagram-design@diagram-design" = true;
        };
      };
  };
}

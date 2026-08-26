# diagram-design (github:cathrynlavery/diagram-design): Editorial diagrams your
# designer won't hate — 39 visual diagram types for AI coding agents.
{ inputs, ... }:
{
  flake-file.inputs.diagram-design = {
    url = "github:cathrynlavery/diagram-design";
    flake = false;
  };

  den.aspects.applications.dev.ai.skills.diagram-design = {
    agent-extensions = {
      type = "plugin";
      marketplace = {
        name = "diagram-design";
        src = inputs.diagram-design;
        pluginId = "diagram-design@diagram-design";
      };
      skills = {
        diagram-design = inputs.diagram-design;
      };
    };
  };
}

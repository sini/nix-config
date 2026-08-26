# diagram-mermaid-render: ASCII & SVG diagram rendering for terminal visualization
# via `mermaid-cli`.
{
  den.aspects.applications.dev.ai.skills.diagram-mermaid-render = {
    agent-extensions = {
      type = "skill";
      skills = {
        diagram-mermaid-render = ./assets/diagram-mermaid-render;
      };
    };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.mermaid-cli
        ];
      };
  };
}

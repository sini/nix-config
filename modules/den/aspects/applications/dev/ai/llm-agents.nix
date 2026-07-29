# numtide/llm-agents.nix CLI tooling for coding agents (beads, codegraph, hunk,
# rtk, …). The Claude Code companion skills for these tools live with the rest of
# the claude skills under mcp/_skills and are registered by the claude aspect.
{
  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  den.aspects.applications.dev.ai.llm-agents = {
    homeManager =
      { pkgs, inputs', ... }:
      {
        # These tools have their own aspects that own their Claude Code wiring:
        # beads (→ beads.nix, github:gastownhall/beads), hunk (→ hunk.nix, numtide
        # package + upstream skill), rtk (→ rtk.nix, numtide binary + skill + hook).
        # The rest stay here on the numtide collection.
        home.packages = [
          inputs'.llm-agents.packages.beads-viewer
          inputs'.llm-agents.packages.codegraph
          pkgs.playwright-mcp
        ];

        programs.git.ignores = [
          "/AGENTS.md"
          "/graphify-out/"
        ];
      };
  };
}

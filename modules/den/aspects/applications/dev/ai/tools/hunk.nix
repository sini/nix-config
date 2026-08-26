# hunk (upstream: github:modem-dev/hunk): a terminal diff viewer for reviewing
# agent changes. The binary comes from the numtide llm-agents collection (a plain
# derivation) rather than modem-dev/hunk's own flake: that flake is a flake-parts
# flake that eagerly evaluates every declared system's formatter, and current
# nixos-unstable (26.11) refuses x86_64-darwin, so evaluating it breaks even a
# linux host. The Claude Code skill is still sourced from the same upstream tree
# (skills/hunk-review), which the numtide package exposes via `.src`.
{
  den.aspects.applications.dev.ai.tools.hunk = {
    homeManager =
      { inputs', ... }:
      {
        home.packages = [ inputs'.llm-agents.packages.hunk ];

        # Inert unless the claude aspect enables programs.claude-code on this host.
        programs.claude-code.skills.hunk-review = "${inputs'.llm-agents.packages.hunk.src}/skills/hunk-review";
      };
  };
}

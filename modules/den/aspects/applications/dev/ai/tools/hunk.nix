# hunk (upstream: github:modem-dev/hunk): a terminal diff viewer for reviewing
# agent changes. The binary comes from the numtide llm-agents collection.
{
  den.aspects.applications.dev.ai.tools.hunk = {
    agent-extensions =
      { inputs', ... }:
      {
        type = "skill";
        skills = {
          # Upstream moved the skill under the hunk package in the monorepo;
          # the top-level skills/ dir now holds only release/video skills.
          hunk-review = "${inputs'.llm-agents.packages.hunk.src}/packages/hunk/skills/hunk-review";
        };
      };

    homeManager =
      { inputs', ... }:
      {
        home.packages = [ inputs'.llm-agents.packages.hunk ];
      };
  };
}

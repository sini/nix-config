# agent-quota: installs the local package of the same name.
#
# One line per agent and bucket with the remaining quota and its reset time, read
# without credentials: agy from `agy -p /quota`, codex from the rate_limits its newest
# session rollout recorded (stamped with the rollout's age). It finds `agy` on PATH,
# which the antigravity-cli aspect provides beside it in roles.dev.
{
  den.aspects.applications.dev.ai.tools.agent-quota = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.local.agent-quota ];
      };
  };
}

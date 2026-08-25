# rtk (github:rtk-ai/rtk, "Rust Token Killer"): a CLI proxy that compresses the
# output of common dev commands before it reaches the model (60-90% fewer tokens).
# Its own aspect bundling the three pieces that make it work: the binary, the
# companion skill, and the transparent PreToolUse rewrite hook. The binary still
# comes from the numtide collection (llm-agents) — only beads/hunk moved to their
# canonical upstreams.
{
  den.aspects.applications.dev.ai.rtk = {
    homeManager =
      { inputs', ... }:
      {
        home.packages = [ inputs'.llm-agents.packages.rtk ];

        programs.claude-code = {
          skills.rtk = ./rtk;

          # The hook rewrites eligible Bash commands to their rtk equivalents
          # before execution, so every command (and subagent) gets the savings
          # with no per-command context overhead. This is exactly what
          # `rtk init -g --hook-only` installs; rtk must be on PATH (above) both
          # for the hook and for the rewritten `rtk <cmd>` it emits.
          settings.hooks.PreToolUse = [
            {
              matcher = "Bash";
              hooks = [
                {
                  type = "command";
                  command = "rtk hook claude";
                }
              ];
            }
          ];
        };
      };
  };
}

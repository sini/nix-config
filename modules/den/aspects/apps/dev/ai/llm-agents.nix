# The claude-code toolchain (binaries). Pulls in `claude-config` (settings + the
# .claude state map) — den merges quirks across files but NOT a class function, so
# the config's `homeManager` lives in its own aspect rather than a second
# `claude.homeManager` here (which would last-wins-clobber this one). replicate.nix
# adds the replicated dir set onto `claude` directly (a quirk, so it merges).
{ den, ... }:
{
  flake-file.inputs.llm-agents.url = "gh:numtide/llm-agents.nix";

  den.aspects.apps.dev.ai.llm-agents = {
    homeManager =
      { pkgs, inputs', ... }:
      {
        home.packages = [
          inputs'.llm-agents.packages.beads-rust
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

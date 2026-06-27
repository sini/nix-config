# The claude-code toolchain (binaries). Pulls in `claude-config` (settings + the
# .claude state map) — den merges quirks across files but NOT a class function, so
# the config's `homeManager` lives in its own aspect rather than a second
# `claude.homeManager` here (which would last-wins-clobber this one). replicate.nix
# adds the replicated dir set onto `claude` directly (a quirk, so it merges).
{ inputs, den, ... }:
{
  den.aspects.apps.dev.ai.claude = {
    includes = [ den.aspects.apps.dev.ai.claude-config ];

    homeLinux =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.socat
          pkgs.bubblewrap
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
          inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.crush
          pkgs.nodejs_22
          # pkgs.markitdown
        ];
      };
  };
}

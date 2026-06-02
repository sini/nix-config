{ inputs, ... }:
{
  den.aspects.apps.dev.claude = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
          inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.crush
          pkgs.nodejs_22
          pkgs.socat
          pkgs.bubblewrap
          # pkgs.markitdown
        ];

        git.ignores = [
          ".claude"
        ];
      };

    persistHome = {
      directories = [
        ".claude"
      ];
    };
  };
}

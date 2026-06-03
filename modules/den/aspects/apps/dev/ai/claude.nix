{ inputs, ... }:
{
  den.aspects.apps.dev.ai.claude = {

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

        programs.git.ignores = [
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

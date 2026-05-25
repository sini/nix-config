{ inputs, ... }:
{
  den.aspects.apps.claude = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
          inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.crush
        ];
      };

    persistHome = {
      directories = [
        ".claude"
      ];
    };
  };
}

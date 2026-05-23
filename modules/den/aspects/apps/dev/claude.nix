{ inputs, ... }:
{
  den.aspects.apps.claude = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          inputs.nix-ai-tools.packages.${pkgs.system}.claude-code
          inputs.nix-ai-tools.packages.${pkgs.system}.crush
        ];
      };

    persistHome = {
      directories = [
        ".claude"
      ];
    };
  };
}

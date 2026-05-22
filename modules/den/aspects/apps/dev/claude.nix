{ den, ... }:
{
  den.aspects.apps.claude = {
    homeManager =
      { inputs, pkgs, ... }:
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

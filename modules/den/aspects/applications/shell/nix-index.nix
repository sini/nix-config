{ inputs, ... }:
{
  den.aspects.applications.shell.nix-index = {
    homeManagerModules =
      { inputs', ... }:
      [
        inputs'.nix-index-database.homeModules.default
      ];

    homeManager = {
      programs.command-not-found.enable = false;
      programs.nix-index = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
        enableZshIntegration = true;
      };
    };
  };
}

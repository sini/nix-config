{
  features.nix-index = {
    system =
      { inputs, ... }:
      {
        home-manager.sharedModules = [ inputs.nix-index-database.homeModules.default ];
      };

    home = {
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

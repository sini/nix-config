{ inputs, ... }:
{
  den.aspects.apps.shell.nix-index = {
    os = _: {
      home-manager.sharedModules = [ inputs.nix-index-database.homeModules.default ];
    };

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

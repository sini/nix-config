{ den, inputs, ... }:
{
  den.aspects.nix-index = {
    _ = {
      system = den.lib.perHost {
        nixos = {
          home-manager.sharedModules = [ inputs.nix-index-database.homeModules.default ];
        };
      };

      home = den.lib.perUser {
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
    };
  };
}

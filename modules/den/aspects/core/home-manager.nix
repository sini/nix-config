# Home-manager NixOS module configuration.
# Den's home-manager battery handles importing the HM NixOS module itself.
# This aspect sets shared config (useGlobalPkgs, useUserPackages, sharedModules).
_: {
  den.aspects.core.home-manager = {
    nixos = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = ".hm-backup";

      home-manager.sharedModules = [
        (
          { osConfig, ... }:
          {
            home.stateVersion = osConfig.system.stateVersion;
            # HM master is 26.05 while nixpkgs-unstable bumped to 26.11
            home.enableNixpkgsReleaseCheck = false;
            programs.home-manager.enable = true;
            systemd.user.startServices = "sd-switch";
          }
        )
      ];
    };

    darwin = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = ".hm-backup";

      home-manager.sharedModules = [
        (
          { lib, ... }:
          {
            home.stateVersion = lib.trivial.release;
            home.enableNixpkgsReleaseCheck = false;
            programs.home-manager.enable = true;
          }
        )
      ];
    };
  };
}

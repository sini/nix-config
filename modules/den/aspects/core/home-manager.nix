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
          { osConfig, lib, ... }:
          {
            home.stateVersion = osConfig.system.stateVersion;
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
            programs.home-manager.enable = true;
          }
        )
      ];
    };
  };
}

# Home-manager NixOS module configuration.
# Den's home-manager battery handles importing the HM NixOS module itself.
# This aspect sets shared config (useGlobalPkgs, useUserPackages, sharedModules).
{
  den.aspects.core.users.home-manager = {
    os = {
      home-manager.useGlobalPkgs = false;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = ".hm-backup";

      home-manager.sharedModules = [
        {
          programs.home-manager.enable = true;
          home.enableNixpkgsReleaseCheck = false;
        }
      ];
    };

    nixos = {
      home-manager.sharedModules = [
        (
          { osConfig, ... }:
          {
            home.stateVersion = osConfig.system.stateVersion;
            systemd.user.startServices = "sd-switch";
          }
        )
      ];
    };

    darwin = {
      home-manager.sharedModules = [
        (
          { lib, ... }:
          {
            home.stateVersion = lib.trivial.release;
          }
        )
      ];
    };
  };
}

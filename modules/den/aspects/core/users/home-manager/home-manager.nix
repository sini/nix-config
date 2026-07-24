# Home-manager NixOS module configuration.
# Den's home-manager battery handles importing the HM NixOS module itself.
# This aspect sets shared config (useGlobalPkgs, useUserPackages, sharedModules).
{ lib, ... }:
{
  den.aspects.core.users.home-manager-shared = {
    settings.useGlobalPkgs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Home-manager shares the host's nixpkgs — its overlays and config — instead
        of evaluating its own pkgs set. User-declared overlays project to the host
        (see the nixpkgs-overlays quirk); when false each user's home-manager
        collects its own overlays as before.
      '';
    };

    os =
      {
        host,
        inputs',
        self',
        ...
      }:
      {
        home-manager.useGlobalPkgs = host.settings.core.users.home-manager-shared.useGlobalPkgs;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = ".hm-backup";

        home-manager.extraSpecialArgs = {
          inherit inputs' self';
        };

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

    homeManager =
      {
        homeManagerModules,
        ...
      }:
      {
        imports = homeManagerModules;
      };
  };
}

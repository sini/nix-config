{
  den,
  lib,
  ...
}:
{
  den = {
    ctx = {
      # TODO: Per-channel home-manager module import
      # =============================================
      # Den's built-in home-manager provider (den.provides.home-manager) imports
      # its own HM module via inputs.home-manager. Since den recently moved away
      # from being flake-based, it may not carry a home-manager input at all.
      #
      # Our repo has multiple HM versions (home-manager, home-manager-unstable,
      # home-manager-master, home-manager-stable-darwin) paired with channels.
      # We previously imported the channel-matched HM module here, but this
      # conflicts with den's built-in import (double module declaration).
      #
      # Options to fix:
      # 1. Override den's getModule in the home-manager provider to use our inputs
      # 2. Make den's HM provider channel-aware
      # 3. Add inputs.home-manager.follows to den so it uses our default
      #
      # For now, den's built-in handles the import. Config below still applies.

      # HM config only for hosts/users that actually use HM
      hm-host.includes = [ den.aspects.home-manager._.nixConfig ];
      hm-user.includes = [ den.aspects.home-manager._.hmConfig ];
    };

    aspects.home-manager = {
      _ = {
        nixConfig = den.lib.perHost {
          nixos.home-manager = {
            useUserPackages = lib.mkDefault true;
            useGlobalPkgs = lib.mkDefault true;
            backupFileExtension = lib.mkDefault "hm-backup";
            overwriteBackup = lib.mkDefault true;
          };
        };

        hmConfig = {
          homeManager.home.stateVersion = lib.mkDefault "25.11";
        };
      };
    };
  };
}

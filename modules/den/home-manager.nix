{
  den,
  lib,
  ...
}:
{
  den = {
    ctx = {
      # HM module import handled by den's built-in provider reading host.home-manager.module
      # (set automatically from channel in schema.nix)

      # HM config for hosts/users that use HM
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

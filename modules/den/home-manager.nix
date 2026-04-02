{ den, lib, ... }:
{
  den = {
    ctx.hm-host.includes = [ den.aspects.home-manager._.nixConfig ];
    ctx.hm-user.includes = [ den.aspects.home-manager._.hmConfig ];

    aspects.home-manager = {
      _.nixConfig = den.lib.perHost {
        nixos.home-manager = {
          useUserPackages = lib.mkDefault true;
          useGlobalPkgs = lib.mkDefault true;
          backupFileExtension = lib.mkDefault "backup";
          overwriteBackup = lib.mkDefault true;
        };
      };

      _.hmConfig = {
        homeManager.home.stateVersion = lib.mkDefault "25.11";
      };
    };
  };
}

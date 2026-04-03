{
  den,
  lib,
  inputs,
  ...
}:
let
  # Always import HM NixOS module on all hosts (matching old builder behavior)
  hm-nixos-module = den.lib.perHost {
    nixos.imports = [ inputs.home-manager-unstable.nixosModules.home-manager ];
  };
in
{
  den = {
    ctx = {
      # Import HM module on ALL hosts via host context (not just hosts with HM users)
      host.includes = [ hm-nixos-module ];

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
            backupFileExtension = lib.mkDefault "backup";
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

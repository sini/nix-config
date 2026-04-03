{ den, lib, ... }:
{
  # The existing modules/den/home-manager.nix already covers useGlobalPkgs,
  # useUserPackages, backupFileExtension, and stateVersion.
  # This aspect adds backupFileExtension override (to match the old ".hm-backup" value)
  # and any remaining system-level HM config not yet covered.
  den.aspects.home-manager-feature = den.lib.perHost {
    nixos.home-manager.backupFileExtension = lib.mkForce ".hm-backup";
  };
}

{ lib, ... }:
{
  den.aspects.core.network.syncthing.settings.isHub = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether this host is the always-on Syncthing hub for replicated home dirs";
  };
}

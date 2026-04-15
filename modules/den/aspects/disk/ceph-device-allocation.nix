{ den, lib, ... }:
{
  # Settings-only aspect: declares the Ceph OSD device path for rook-ceph.
  # Hosts set den.schema.host.settings.ceph-device-allocation.device.
  den.aspects.ceph-device-allocation = {
    settings = {
      device = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Full device path for Ceph OSD (e.g., /dev/disk/by-id/nvme-...).";
      };
    };
  };
}

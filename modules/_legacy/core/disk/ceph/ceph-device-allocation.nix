# Declares the Ceph OSD device path for this host, consumed by rook-ceph.
{ lib, ... }:
{
  features.ceph-device-allocation = {
    settings = {
      device = lib.mkOption {
        type = lib.types.str;
        description = "Full device path for Ceph OSD (e.g., /dev/disk/by-id/nvme-...).";
      };
    };
  };
}

{ den, ... }:
{
  # Settings-only aspect: declares the Ceph OSD device path for rook-ceph.
  # Hosts set den.schema.host.settings.ceph-device-allocation.device.
  den.aspects.ceph-device-allocation = den.lib.perHost { };
}

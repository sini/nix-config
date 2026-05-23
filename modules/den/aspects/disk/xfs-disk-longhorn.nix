{ lib, inputs, ... }:
{
  den.aspects.disk.xfs-disk-longhorn = {
    settings = {
      device_id = lib.mkOption {
        type = lib.types.str;
        description = "Longhorn data drive full device path (e.g., /dev/disk/by-id/nvme-...).";
      };
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/longhorn";
        description = "Mount point for the Longhorn data drive.";
      };
    };

    nixos =
      { host, pkgs, ... }:
      let
        cfg = host.settings.disk.xfs-disk-longhorn;

        defaultMountOpts = [
          "defaults"
          "noatime"
          "nodiratime"
          "discard"
          "largeio"
          "allocsize=64k"
        ];
      in
      {
        imports = [ inputs.disko.nixosModules.default ];

        environment.systemPackages = [ pkgs.xfsprogs ];

        assertions = [
          {
            assertion = cfg.device_id != "";
            message = "den: disk.xfs-disk-longhorn.device_id must be set";
          }
        ];

        disko.devices.disk.data = {
          device = cfg.device_id;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              longhorn = {
                label = "longhorn";
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "xfs";
                  mountpoint = cfg.mountPoint;
                  mountOptions = defaultMountOpts;
                };
              };
            };
          };
        };
      };
  };
}

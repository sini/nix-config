# NixOS module for configuring a dedicated Longhorn data drive (XFS, no encryption).
{ inputs, ... }:
{
  flake.features.xfs-disk-longhorn.linux =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.hardware.disk.longhorn;

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

      options.hardware.disk.longhorn = {
        device_id = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Longhorn data drive full device path (e.g., /dev/disk/by-id/nvme-...).";
        };

        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/longhorn";
          description = "Mount point for the Longhorn data drive.";
        };
      };

      config = {
        environment.systemPackages = with pkgs; [ xfsprogs ];

        assertions = [
          {
            assertion = cfg.device_id != "";
            message = "hardware.disk.longhorn.device_id must be set.";
          }
        ];

        disko.devices.disk.data = lib.mkIf (cfg.device_id != "") {
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

{ den, lib, ... }:
{
  den.aspects.xfs-disk-longhorn = {
    includes = lib.attrValues den.aspects.xfs-disk-longhorn._;

    _ = {
      config = den.lib.perHost (
        { host }:
        {
          nixos =
            { lib, pkgs, ... }:
            let
              cfg = host.settings.xfs-disk-longhorn;

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
              environment.systemPackages = with pkgs; [ xfsprogs ];

              assertions = [
                {
                  assertion = cfg.device_id != "";
                  message = "settings.xfs-disk-longhorn.device_id must be set.";
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
        }
      );
    };
  };
}

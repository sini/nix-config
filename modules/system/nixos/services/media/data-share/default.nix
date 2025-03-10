{
  options,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.services.media.data-share;
in
{
  options.services.media.data-share = with types; {
    enable = mkBoolOpt false "Enable NFS data share mount";
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [
      "nfs"
      "nfs4"
    ];

    services.rpcbind.enable = true; # needed for NFS

    fileSystems =
      let
        commonOptions = [
          "_netdev"
          "nfsvers=4.1"
          "noauto"
          "noatime"
          "x-systemd.automount"
          "x-systemd.idle-timeout=600"
        ];
      in
      {
        "/mnt/data" = {
          device = "10.10.10.10:/volume2/data";
          fsType = "nfs4";
          options = commonOptions;
        };

        "/volume1/NVME" = {
          device = "10.10.10.10:/volume1/NVME";
          fsType = "nfs4";
          options = commonOptions;
        };

        "/volume1/docker" = {
          device = "10.10.10.10:/volume1/docker";
          fsType = "nfs4";
          options = commonOptions;
        };
      };

  };
}

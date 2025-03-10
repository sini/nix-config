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

    fileSystems."/mnt/data" = {
      device = "10.10.10.10:/volume2/data";
      fsType = "nfs4";
      options = [
        "_netdev"
        "nfsvers=4.1"
        "noauto"
        "noatime"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
      ];
    };

    # systemd.mounts =
    #   let
    #     commonMountOptions = {
    #       type = "nfs";
    #       mountConfig = {
    #         Options = "noatime,nfsvers=4.1,remoteaddrs=10.10.10.10-10.10.10.12";
    #       };
    #     };
    #   in

    #   [
    #     (
    #       commonMountOptions
    #       // {
    #         what = "10.10.10.10:/volume2/data";
    #         where = "/mnt/data";
    #       }
    #     )

    #     (
    #       commonMountOptions
    #       // {
    #         what = "10.10.10.10:/volume1/NVME";
    #         where = "/mnt/NVME";
    #       }
    #     )

    #     (
    #       commonMountOptions
    #       // {
    #         what = "10.10.10.10:/volume1/docker";
    #         where = "/mnt/docker";
    #       }
    #     )
    #   ];

    # systemd.automounts =
    #   let
    #     commonAutoMountOptions = {
    #       wantedBy = [ "multi-user.target" ];
    #       automountConfig = {
    #         TimeoutIdleSec = "600";
    #       };
    #     };
    #   in

    #   [
    #     (commonAutoMountOptions // { where = "/mnt/data"; })
    #     (commonAutoMountOptions // { where = "/mnt/NVME"; })
    #     (commonAutoMountOptions // { where = "/mnt/docker"; })
    #   ];

  };
}

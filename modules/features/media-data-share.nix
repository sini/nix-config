{
  flake.modules = {
    nixos.media-data-share = {
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
        };
    };
  };
}

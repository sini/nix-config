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
  cfg = config.services.data-share;
in
{
  options.services.data-share = with types; {
    enable = mkBoolOpt false "Enable NFS data share mount";
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [
      "nfs"
      "nfs4"
    ];

    fileSystems."/mnt/data" = {
      device = "10.10.10.10:/volume2/data";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=300"
        "noatime"
        "nfsvers=4.1"
      ];
    };
    #fileSystems."/mnt/NAS" = { device = "srv-prod-nas.home.address:/mnt/Main Storage/USER_NAME/USER_NAME"; fsType = "nfs"; };
  };
}

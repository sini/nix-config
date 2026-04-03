# ZFS runtime support: boot config, kernel params, packages, scrub, trim
{ den, ... }:
{
  den.aspects.zfs-root = den.lib.perHost {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          lzop
          mbuffer
          pv
        ];

        boot = {
          supportedFilesystems.zfs = true;

          zfs = {
            package = pkgs.zfs_2_4;
            devNodes = "/dev/disk/by-id/";
            forceImportAll = true;
            requestEncryptionCredentials = [ "zroot" ];
          };

          kernelParams = [
            "zfs.zfs_arc_max=${toString (16 * 1024 * 1024 * 1024)}"
            "elevator=none"
            "nohibernate"
          ];
        };

        # https://github.com/openzfs/zfs/issues/10891
        systemd.services.systemd-udev-settle.enable = false;

        services.zfs = {
          expandOnBoot = "all";
          autoScrub.enable = true;
          autoScrub.interval = "weekly";
          trim.enable = true;
        };
      };
  };
}

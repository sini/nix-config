{
  flake.features.zfs = {
    requires = [ "zfs-diff" ];

    nixos =
      { pkgs, ... }:
      {

        environment.systemPackages = with pkgs; [
          lzop
          mbuffer
          pv
        ];

        boot.supportedFilesystems.zfs = true;

        boot.zfs = {
          package = pkgs.zfs_2_4;
          # package = pkgs.zfs_cachyos;
          # package = config.boot.kernelPackages.zfs_unstable;
          # package = pkgs.cachyosKernels.zfs-cachyos.override {
          #   kernel = config.boot.kernelPackages.kernel;
          # };
          devNodes = "/dev/disk/by-id/";
          forceImportAll = true;
          requestEncryptionCredentials = [ "zroot" ];
        };

        # https://github.com/openzfs/zfs/issues/10891
        systemd.services.systemd-udev-settle.enable = false;

        boot.kernelParams = [
          # ZFS-related params
          "zfs.zfs_arc_max=${toString (16 * 1024 * 1024 * 1024)}"
          "elevator=none"
          "nohibernate"
        ];

        services.zfs = {
          # Expand all devices on boot
          expandOnBoot = "all";

          # Enable auto-scrub
          autoScrub.enable = true;
          autoScrub.interval = "weekly";

          trim.enable = true;
        };

        # # Enable ZED's pushbullet compat
        # services.zfs.zed.settings = {
        #   ZED_DEBUG_LOG = "/tmp/zed.debug.log";
        #   ZED_NOTIFY_VERBOSE = "1";
        #   ZED_SLACK_WEBHOOK_URL = my.secrets.discord.webhook + "/slack";
        # };

        #         # setup zfs event daemon for email notifications
        # (mkIf config.custom.zfs.zed {
        #   sops.secrets.zfs-zed.owner = user;

        #   # setup email for zfs event daemon to use
        #   programs.msmtp = {
        #     enable = true;
        #     setSendmail = true;
        #     accounts = {
        #       default = {
        #         host = "smtp.gmail.com";
        #         tls = true;
        #         auth = true;
        #         port = 587;
        #         inherit user;
        #         from = "email@gmail.com";
        #         # app specific password needed for 2fa
        #         passwordeval = "cat ${config.sops.secrets.zfs-zed.path}";
        #       };
        #     };
        #   };

        #   services.zfs.zed = {
        #     enableMail = true;
        #     settings = {
        #       ZED_DEBUG_LOG = "/tmp/zed.debug.log";
        #       ZED_EMAIL_ADDR = [ "email@gmail.com" ];
        #       ZED_EMAIL_PROG = getExe pkgs.msmtp;
        #       ZED_EMAIL_OPTS = "@ADDRESS@";

        #       ZED_NOTIFY_INTERVAL_SECS = 3600;
        #       ZED_NOTIFY_DATA = true;
        #       ZED_NOTIFY_VERBOSE = true;

        #       ZED_USE_ENCLOSURE_LEDS = false;
        #       ZED_SCRUB_AFTER_RESILVER = true;
        #     };
        #   };

      };
  };
}

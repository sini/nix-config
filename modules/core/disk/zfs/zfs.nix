{
  flake.features.zfs = {
    requires = [ "zfs-diff" ];

    nixos =
      { pkgs, ... }:
      {
        boot.supportedFilesystems.zfs = true;

        boot.zfs = {
          package = pkgs.zfs_cachyos;
          devNodes = "/dev/disk/by-id/";
          forceImportAll = true;
          requestEncryptionCredentials = [ "zroot" ];
        };

        boot.kernelParams = [
          # ZFS-related params
          "zfs.zfs_arc_max=${toString (16 * 1024 * 1024 * 1024)}"
          "elevator=none"
          "nohibernate"
        ];

        # Expand all devices on boot
        services.zfs.expandOnBoot = "all";

        # Enable auto-scrub
        services.zfs.autoScrub.enable = true;
        services.zfs.autoScrub.interval = "weekly";

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

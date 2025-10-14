{
  flake.features.zfs.nixos =
    { pkgs, ... }:
    {
      boot.zfs.package = pkgs.zfs_cachyos;

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

      # Enable auto-trim
      services.zfs.trim.enable = true;
      services.zfs.trim.interval = "daily";

      # Enable auto-snapshot
      services.zfs.autoSnapshot = {
        enable = true;
        monthly = 0;
        weekly = 0;
        daily = 2;
      };

      # # Enable ZED's pushbullet compat
      # services.zfs.zed.settings = {
      #   ZED_DEBUG_LOG = "/tmp/zed.debug.log";
      #   ZED_NOTIFY_VERBOSE = "1";
      #   ZED_SLACK_WEBHOOK_URL = my.secrets.discord.webhook + "/slack";
      # };

    };
}

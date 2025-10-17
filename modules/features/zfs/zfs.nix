{
  flake.features.zfs.nixos =
    { pkgs, ... }:
    {
      boot.supportedFilesystems.zfs = true;

      boot.zfs = {
        package = pkgs.zfs_cachyos;
        devNodes = "/dev/disk/by-id/";
        forceImportAll = true;
        requestEncryptionCredentials = true;
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

      environment.systemPackages = [
        (pkgs.writeScriptBin "zfs-diff" ''
          sudo zfs diff zroot/local/root@empty -F | ${pkgs.ripgrep}/bin/rg -e "\+\s+/\s+" | cut -f3- | ${pkgs.skim}/bin/sk;
          sudo zfs diff zroot/local/home@empty -F | ${pkgs.ripgrep}/bin/rg -e "\+\s+/\s+" | cut -f3- | ${pkgs.skim}/bin/sk
        '')
      ];
      # # Enable ZED's pushbullet compat
      # services.zfs.zed.settings = {
      #   ZED_DEBUG_LOG = "/tmp/zed.debug.log";
      #   ZED_NOTIFY_VERBOSE = "1";
      #   ZED_SLACK_WEBHOOK_URL = my.secrets.discord.webhook + "/slack";
      # };

    };
}

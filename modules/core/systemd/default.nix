{
  flake.features.systemd.nixos =
    {
      lib,
      activeFeatures,
      ...
    }:
    let
      legacyFs = lib.elem "disk-single" activeFeatures;
    in
    {
      systemd.tmpfiles.rules = [
        # cleanup systemd coredumps once a week
        "d /var/lib/systemd/coredump 0755 root root 7d"
        # Ensure private exists with correct permissions
        "d /var/lib/private 0700 root root -"
        "z /var/lib/private 0700 root root -"
      ];

      impermanence.ignorePaths = [
        "/var/lib/systemd/linger/"
        "/var/lib/systemd/random-seed"
      ];

      environment.persistence."/volatile".files = [
        "/var/lib/lastlog/lastlog2.db"
        "/var/lib/systemd/timesync/clock"
      ];

      environment.persistence."/volatile".directories = [
        "/var/lib/systemd/coredump"
        "/var/lib/systemd/timers"
        "/var/lib/systemd/catalog"
      ]
      ++
        # If using legacy disk-configuration, don't persist logs as they are on their own subvolume
        #TODO: Remove once we kill legacyFs support
        lib.optional (!legacyFs) "/var/log";

      # Limit logging to 90 days or 2gb
      services.journald.extraConfig = ''
        MaxRetentionSec=3month
        SystemMaxUse=2G
      '';
    };
}

{
  flake.modules.nixos.systemd-boot = {
    systemd.tmpfiles.rules = [
      # cleanup systemd coredumps once a week
      "D! /var/lib/systemd/coredump root root 7d"
    ];
    # Limit logging to 90 days or 2gb
    services.journald.extraConfig = ''
      MaxRetentionSec=3month
      SystemMaxUse=2G
    '';
  };
}

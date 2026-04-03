{ den, lib, ... }:
{
  den.aspects.systemd = {
    includes = lib.attrValues den.aspects.systemd._;

    _ = {
      config = den.lib.perHost {
        nixos = {
          systemd.tmpfiles.rules = [
            # cleanup systemd coredumps once a week
            "d /var/lib/systemd/coredump 0755 root root 7d"
          ];

          # Limit logging to 90 days or 2gb
          services.journald.extraConfig = ''
            MaxRetentionSec=3month
            SystemMaxUse=2G
          '';
        };
      };

      impermanence = den.lib.perHost {
        nixos = {
          environment.persistence."/cache".files = [
            "/var/lib/lastlog/lastlog2.db"
          ];

          environment.persistence."/cache".directories = [
            "/var/lib/systemd/coredump"
            "/var/lib/systemd/timers"
            "/var/lib/systemd/catalog"
            "/var/log"
            {
              directory = "/var/lib/systemd/network";
              mode = "0755";
              user = "systemd-network";
              group = "systemd-network";
            }
          ];
        };
      };
    };
  };
}

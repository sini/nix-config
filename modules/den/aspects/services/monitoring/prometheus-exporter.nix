# Prometheus exporters for system monitoring.
#
# Ported from main:modules/services/monitoring/prometheus-exporter/prometheus.nix.
_: {
  den.aspects.services.monitoring.prometheus-exporter = {
    nixos =
      { pkgs, lib, ... }:
      {
        services.prometheus = {
          exporters = {
            node = {
              enable = lib.mkDefault true;
              port = lib.mkDefault 9100;
              enabledCollectors = [
                "cpu"
                "diskstats"
                "filesystem"
                "loadavg"
                "meminfo"
                "meminfo_numa"
                "netdev"
                "netstat"
                "network_route"
                "tcpstat"
                "textfile"
                "time"
                "uname"
                "vmstat"
                "logind"
                "interrupts"
                "ksmd"
                "processes"
                "systemd"
                "filefd"
                "hwmon"
                "mountstats"
                "sockstat"
                "stat"
                "wifi"
              ];
              extraFlags = [
                "--collector.filesystem.mount-points-exclude='^/(persist/|cache/)?(home|var/lib/private|sys|proc|dev|etc|root|run)($$|/)'"
                "--collector.filesystem.ignored-fs-types=^(sys|proc|auto)fs$$"
              ];
            };

            process = {
              enable = lib.mkDefault true;
              port = lib.mkDefault 9256;
              settings.process_names = lib.mkDefault [
                {
                  name = "{{.Comm}}";
                  cmdline = [ "node_exporter" ];
                }
                {
                  name = "{{.Comm}}";
                  cmdline = [ "systemd_exporter" ];
                }
                {
                  name = "{{.Comm}}";
                  cmdline = [ "process_exporter" ];
                }
              ];
            };

            blackbox = {
              enable = lib.mkDefault false;
              port = 9115;
              configFile = pkgs.writeText "blackbox.yml" ''
                modules:
                  http_2xx:
                    prober: http
                    timeout: 5s
                    http:
                      preferred_ip_protocol: "ip4"
                  http_post_2xx:
                    prober: http
                    timeout: 5s
                    http:
                      method: POST
                  tcp_connect:
                    prober: tcp
                    timeout: 5s
                  icmp:
                    prober: icmp
                    timeout: 5s
                    icmp:
                      preferred_ip_protocol: "ip4"
              '';
            };
          };
        };

        environment.systemPackages = with pkgs; [
          htop
          iotop
          nethogs
          smartmontools
          lm_sensors
          sysstat
          perf-tools
          iftop
          nload
        ];

        networking.firewall.allowedTCPPorts = [ 9100 ];
      };
  };
}

# Prometheus exporters for system monitoring.
#
# Ported from main:modules/services/monitoring/prometheus-exporter/prometheus.nix.
{
  den.aspects.services.monitoring.prometheus-exporter = {
    # Scraped by the environment's ingester (services.monitoring.prometheus).
    prometheus-targets =
      { environment, host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit environment;
        exporters = [
          {
            job = "node-exporter";
            port = 9100;
          }
        ];
      };

    nixos =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        # Impermanence bind-mounts each persisted path from its dataset, so
        # node-exporter would report one dataset once per path, each alerting on
        # its own; the dataset's own mount is the one to keep.
        persisted = lib.concatMap (p: map (d: d.dirPath) p.directories ++ map (f: f.filePath) p.files) (
          lib.attrValues (config.environment.persistence or { })
        );
        excludedMounts = [
          "/(persist/|cache/)?(home|var/lib/private|sys|proc|dev|etc|root|run)"
        ]
        # `[.]`, not `\.`: the flag passes through ExecStart, which reads backslashes.
        ++ map (lib.replaceStrings [ "." ] [ "[.]" ]) persisted;
      in
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
                "--collector.filesystem.mount-points-exclude='^(${lib.concatStringsSep "|" excludedMounts})($$|/)'"
                # virtiofs is a share of the host's own filesystem, already reported there.
                "--collector.filesystem.ignored-fs-types=^(sys|proc|auto|virtio)fs$$"
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

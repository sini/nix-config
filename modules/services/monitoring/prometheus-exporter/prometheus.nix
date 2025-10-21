{
  flake.features.prometheus-exporter.nixos =
    {
      pkgs,
      lib,
      ...
    }:
    {
      # Prometheus exporters for system monitoring
      services.prometheus = {
        exporters = {
          # Node exporter for system metrics
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
              "--collector.filesystem.mount-points-exclude='^/(persist/|volatile/)?(home|var/lib/private|sys|proc|dev|etc|root|run)($$|/)'"
              "--collector.filesystem.ignored-fs-types=^(sys|proc|auto)fs$$"
            ];
          };

          # Process exporter for process metrics
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

          # Blackbox exporter for network monitoring
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

      # System monitoring packages
      environment.systemPackages = with pkgs; [
        # System monitoring tools
        htop
        iotop
        nethogs
        smartmontools
        lm_sensors

        # Performance analysis
        sysstat
        perf-tools

        # Network monitoring
        iftop
        nload
        nethogs
      ];
    };
}

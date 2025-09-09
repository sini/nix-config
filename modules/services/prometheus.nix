# { rootPath, ... }:
{
  flake.modules.nixos.prometheus =
    { config, ... }:
    {
      services = {
        prometheus = {
          enable = true;
          port = 9090;
          listenAddress = "127.0.0.1";

          extraFlags = [
            "--storage.tsdb.retention.time=30d"
            "--storage.tsdb.retention.size=10GB"
            "--web.enable-lifecycle"
          ];

          scrapeConfigs = [
            {
              job_name = "prometheus";
              static_configs = [
                {
                  targets = [ "127.0.0.1:9090" ];
                }
              ];
            }
            {
              job_name = "node-exporter";
              static_configs = [
                {
                  targets = [ "127.0.0.1:9100" ];
                }
              ];
            }
            {
              job_name = "nginx-exporter";
              static_configs = [
                {
                  targets = [ "127.0.0.1:9113" ];
                }
              ];
            }
          ];

          rules = [
            ''
              groups:
                - name: node-exporter
                  rules:
                    - alert: HighCPUUsage
                      expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "High CPU usage detected"
                        description: "CPU usage is above 80% for more than 5 minutes"

                    - alert: HighMemoryUsage
                      expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "High memory usage detected"
                        description: "Memory usage is above 85% for more than 5 minutes"

                    - alert: DiskSpaceLow
                      expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 90
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Disk space running low"
                        description: "Disk usage is above 90% for more than 5 minutes"
            ''
          ];
        };

        prometheus.exporters = {
          node = {
            enable = true;
            port = 9100;
            listenAddress = "127.0.0.1";
            enabledCollectors = [
              "processes"
              "interrupts"
              "ksmd"
              "logind"
              "meminfo_numa"
              "mountstats"
              "network_route"
              "systemd"
              "tcpstat"
              "wifi"
            ];
          };

          nginx = {
            enable = true;
            port = 9113;
            listenAddress = "127.0.0.1";
          };
        };

        nginx.virtualHosts = {
          "prometheus.${config.networking.domain}" = {
            forceSSL = true;
            useACMEHost = config.networking.domain;
            locations."/" = {
              proxyPass = "http://127.0.0.1:9090";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
          };
        };
      };

      # Enable nginx status for nginx exporter
      services.nginx.statusPage = true;

      # Open firewall for node exporter (so other hosts can scrape)
      networking.firewall.allowedTCPPorts = [ 9100 ];
    };
}

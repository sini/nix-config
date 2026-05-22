# Prometheus — time-series monitoring with auto-discovery via prometheus-targets
# quirk, alert rules, 30d retention, nginx proxy, remote-write receiver.
#
# Ported from main:modules/services/monitoring/prometheus.nix
{
  den,
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.services.prometheus = {
    nixos =
      {
        config,
        host,
        ...
      }:
      let
        env = environments.${host.environment};
        domain = env.getDomainFor "prometheus";

        # Collect prometheus-targets quirk data from all aspects on this host.
        # Each entry is { job_name, port, ?path, ?interval }.
        collectedTargets = host.quirks.prometheus-targets or [ ];

        # Build scrape configs from collected targets, grouping by job_name
        # and pointing at the host's own address.
        targetScrapeConfigs = lib.pipe collectedTargets [
          (lib.groupBy (t: t.job_name))
          (lib.mapAttrsToList (
            job_name: targets:
            let
              first = builtins.head targets;
            in
            {
              inherit job_name;
              static_configs = map (t: {
                targets = [ "127.0.0.1:${toString t.port}" ];
                labels = {
                  hostname = config.networking.hostName;
                  exporter = t.job_name;
                };
              }) targets;
              metrics_path = first.path or "/metrics";
              scrape_interval = first.interval or "15s";
            }
          ))
        ];
      in
      {
        services = {
          prometheus = {
            enable = true;
            port = 9090;
            listenAddress = "0.0.0.0";

            extraFlags = [
              "--web.enable-remote-write-receiver"
              "--enable-feature=remote-write-receiver"
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
                    labels = {
                      hostname = config.networking.hostName;
                      exporter = "prometheus";
                    };
                  }
                ];
              }
            ]
            ++ targetScrapeConfigs;

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

          nginx.virtualHosts."${domain}" = {
            forceSSL = true;
            useACMEHost = env.domain;
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

    service-domains = [ "prometheus" ];

    firewall = {
      networking.firewall.allowedTCPPorts = [ 9090 ];
    };

    persist = {
      directories = [
        "/var/lib/prometheus2"
      ];
    };
  };
}

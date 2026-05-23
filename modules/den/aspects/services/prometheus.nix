# Prometheus — time-series monitoring with static exporter discovery,
# alert rules, 30d retention, nginx proxy, remote-write receiver.
#
# Emits prometheus-targets quirk; consumes collected targets from all
# peers to build scrape configs.
{
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.services.prometheus = {
    # Emit scrape targets for this host
    prometheus-targets =
      { host, ... }:
      let
        hasK3s = (host.settings.services.k3s or { }) != { };
      in
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit (host) environment;
        exporters = [
          {
            job = "node";
            port = 9100;
          }
        ]
        ++ lib.optionals hasK3s [
          {
            job = "k3s-server";
            port = 10249;
          }
          {
            job = "etcd";
            port = 2381;
          }
        ];
      };

    nixos =
      {
        prometheus-targets,
        config,
        host,
        lib,
        ...
      }:
      let
        env = environments.${host.environment};
        domain = env.getDomainFor "prometheus";

        # Build scrape entries from collected targets in the same environment
        envTargets = lib.filter (t: t.environment == host.environment) prometheus-targets;

        allScrapes = lib.flatten (
          map (
            target:
            map (exp: {
              job_name = exp.job;
              target = "${target.ip}:${toString exp.port}";
              labels = {
                inherit (target) hostname;
                exporter = exp.job;
              };
            }) target.exporters
          ) envTargets
        );

        # Group by job_name and merge targets
        targetScrapeConfigs = lib.pipe allScrapes [
          (lib.groupBy (s: s.job_name))
          (lib.mapAttrsToList (
            job_name: entries: {
              inherit job_name;
              static_configs = map (e: {
                targets = [ e.target ];
                inherit (e) labels;
              }) entries;
              metrics_path = "/metrics";
              scrape_interval = if job_name == "node" then "15s" else "30s";
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
              {
                job_name = "nginx-exporter";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:9113" ];
                    labels = {
                      hostname = config.networking.hostName;
                      exporter = "nginx";
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

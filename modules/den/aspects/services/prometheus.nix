# Prometheus — time-series monitoring with static exporter discovery,
# alert rules, 30d retention, nginx proxy, remote-write receiver.
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
  allHosts = config.den.hosts.x86_64-linux or { };
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

        # Static exporter discovery from allHosts in the same environment.
        # Mirrors main's approach: node-exporter (9100) on all servers,
        # k3s metrics (10249) + etcd (2381) on k3s hosts.
        envHosts = lib.filterAttrs (_: h: h.environment == host.environment) allHosts;

        mkHostScrapes =
          hostname: h:
          let
            ip = builtins.head h.ipv4;
            hasK3s = (h.settings.services.k3s or { }) != { };
          in
          [
            {
              job_name = "node";
              target = "${ip}:9100";
              labels = {
                inherit hostname;
                exporter = "node";
              };
            }
          ]
          ++ lib.optionals hasK3s [
            {
              job_name = "k3s-server";
              target = "${ip}:10249";
              labels = {
                inherit hostname;
                exporter = "k3s-server";
              };
            }
            {
              job_name = "etcd";
              target = "${ip}:2381";
              labels = {
                inherit hostname;
                exporter = "etcd";
              };
            }
          ];

        allScrapes = lib.flatten (lib.mapAttrsToList mkHostScrapes envHosts);

        # Group by job_name and merge targets
        targetScrapeConfigs = lib.pipe allScrapes [
          (lib.groupBy (s: s.job_name))
          (lib.mapAttrsToList (
            job_name: entries: {
              inherit job_name;
              static_configs = map (e: {
                targets = [ e.target ];
                labels = e.labels;
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

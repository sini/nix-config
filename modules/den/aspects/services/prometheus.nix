# Prometheus metrics server with auto-discovered scrape targets.
{ den, lib, ... }:
{
  den.aspects.prometheus = {
    includes = lib.attrValues den.aspects.prometheus._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
          domain = environment.getDomainFor "prometheus";
        in
        {
          nixos =
            { config, lib, ... }:
            let
              currentHostEnvironmentName = host.environment.name;

              # Determine which environments to scan for metrics
              # Include current environment plus any additional ones from monitoring config
              targetEnvironments = [ currentHostEnvironmentName ] ++ environment.monitoring.scanEnvironments;

              # Auto-discover exporters based on host features
              getAutoExporters =
                hostConfig:
                let
                  serverExporters =
                    if true then # TODO: all monitored hosts are servers
                      {
                        node = {
                          port = 9100;
                          path = "/metrics";
                          interval = "15s";
                        };
                      }
                    else
                      { };
                  k3sExporters =
                    if (hostConfig.cluster or null) != null then # TODO: proper k8s check
                      {
                        k3s-server = {
                          port = 10249;
                          path = "/metrics";
                          interval = "30s";
                        };
                        etcd = {
                          port = 2381;
                          path = "/metrics";
                          interval = "30s";
                        };
                      }
                    else
                      { };
                in
                serverExporters // k3sExporters;

              # Generate scrape configs from all exporters on server hosts
              # TODO: migrate to use den.hosts from flake-parts level
              generateScrapeConfigs =
                envs:
                (host.environment.findHostsByFeature "server")
                |> lib.attrsets.filterAttrs (
                  _hostname: hostConfig: builtins.elem (hostConfig.environment or "unknown") envs
                )
                |> lib.mapAttrsToList (
                  hostname: hostConfig:
                  let
                    allExporters = (hostConfig.exporters or { }) // (getAutoExporters hostConfig);
                  in
                  lib.mapAttrsToList (exporterName: exporterConfig: {
                    job_name = "${exporterName}";
                    static_configs = [
                      {
                        targets = [ "${builtins.head hostConfig.ipv4}:${toString exporterConfig.port}" ];
                        labels = {
                          inherit hostname;
                          exporter = exporterName;
                          source_environment = hostConfig.environment;
                        };
                      }
                    ];
                    metrics_path = exporterConfig.path;
                    scrape_interval = exporterConfig.interval;
                  }) allExporters
                )
                |> lib.flatten;

              # Group scrape configs by job name and merge targets
              groupedScrapeConfigs =
                envs:
                let
                  grouped = lib.groupBy (sc: sc.job_name) (generateScrapeConfigs envs);
                in
                lib.mapAttrsToList (
                  job_name: configs:
                  let
                    firstConfig = builtins.head configs;
                    allTargets = lib.flatten (map (c: c.static_configs) configs);
                  in
                  {
                    inherit job_name;
                    static_configs = allTargets;
                    inherit (firstConfig) metrics_path;
                    inherit (firstConfig) scrape_interval;
                  }
                ) grouped;
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
                            server = "true";
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
                            server = "true";
                          };
                        }
                      ];
                    }
                  ]
                  ++ (groupedScrapeConfigs targetEnvironments);

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
                  useACMEHost = environment.getTopDomainFor "prometheus";
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
        }
      );

      firewall = den.lib.perHost {
        firewall.allowedTCPPorts = [ 9090 ];
      };

      impermanence = den.lib.perHost {
        persist.directories = [
          "/var/lib/prometheus2/"
        ];
      };
    };
  };
}

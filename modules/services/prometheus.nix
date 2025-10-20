{
  config,
  lib,
  getAutoExporters,
  ...
}:
let
  # Generate scrape configs from all exporters on server hosts
  generateScrapeConfigs =
    targetEnvironments:
    config.flake.hosts
    |> lib.attrsets.filterAttrs (
      hostname: hostConfig:
      builtins.elem "server" hostConfig.roles && builtins.elem hostConfig.environment targetEnvironments
    )
    |> lib.mapAttrsToList (
      hostname: hostConfig:
      let
        # Merge manual and auto-discovered exporters
        allExporters = (hostConfig.exporters or { }) // (getAutoExporters hostConfig);
      in
      lib.mapAttrsToList (exporterName: exporterConfig: {
        job_name = "${exporterName}";
        static_configs = [
          {
            targets = [ "${builtins.head hostConfig.ipv4}:${toString exporterConfig.port}" ];
            labels = {
              hostname = hostname;
              exporter = exporterName;
              source_environment = hostConfig.environment;
            }
            // (builtins.listToAttrs (
              map (role: {
                name = role;
                value = "true";
              }) hostConfig.roles
            ));
          }
        ];
        metrics_path = exporterConfig.path;
        scrape_interval = exporterConfig.interval;
      }) allExporters
    )
    |> lib.flatten;

  # Group scrape configs by job name and merge targets
  groupedScrapeConfigs =
    targetEnvironments:
    let
      grouped = lib.groupBy (sc: sc.job_name) (generateScrapeConfigs targetEnvironments);
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
        metrics_path = firstConfig.metrics_path;
        scrape_interval = firstConfig.scrape_interval;
      }
    ) grouped;
in
{
  flake.features.prometheus.nixos =
    {
      config,
      hostOptions,
      environment,
      ...
    }:
    let
      currentHostEnvironment = hostOptions.environment;

      # Determine which environments to scan for metrics
      # Include current environment plus any additional ones from monitoring config
      targetEnvironments = [ currentHostEnvironment ] ++ (environment.monitoring.scanEnvironments or [ ]);
    in
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

        prometheus.exporters = {
          nginx = {
            enable = true;
            port = 9113;
            listenAddress = "127.0.0.1";
          };
        };

        nginx = {
          # Enable nginx status for nginx exporter
          statusPage = true;

          virtualHosts = {
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
      };

      environment.persistence."/persist".directories = [
        "/var/lib/prometheus2/"
      ];
    };
}

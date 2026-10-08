# Prometheus — time-series monitoring with static exporter discovery,
# alert rules, 30d retention, nginx proxy, remote-write receiver.
#
# Scrapes every target the environment's hosts announce through the
# prometheus-targets quirk (node exporter, k3s, nginx, headscale, ...).
{ lib, ... }:
let
  serviceDomains = [ "prometheus" ];
in
{
  den.aspects.services.monitoring.prometheus = {
    settings = {
      # The fleet's outside observer: an Alertmanager next to this Prometheus,
      # mailing the environment's admin address for host and control-plane
      # rules. It submits straight to the upstream rather than through the
      # cluster relay, so it still works when the cluster is what failed.
      # null leaves the rules evaluated but routed nowhere.
      alerting = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options.smtp = {
              host = lib.mkOption {
                type = lib.types.str;
                example = "smtp.example.com";
                description = "Upstream submission host (STARTTLS).";
              };
              port = lib.mkOption {
                type = lib.types.port;
                default = 587;
                description = "Upstream submission port.";
              };
              username = lib.mkOption {
                type = lib.types.str;
                example = "infra@example.com";
                description = "SASL login, also the sender address.";
              };
              passwordSecret = lib.mkOption {
                type = lib.types.str;
                example = "smtp-infra-at-example-com.age";
                description = "Age file with the password or token, relative to the environment's secretPath.";
              };
            };
          }
        );
        default = null;
        description = "Alertmanager for this Prometheus; null disables it.";
      };
    };

    # The ingester announces its own Prometheus like any exporter; it is also
    # how alloy finds where to ship (the host exposing job "prometheus").
    prometheus-targets =
      { environment, host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit environment;
        exporters = [
          {
            job = "prometheus";
            port = 9090;
          }
        ];
      };

    nixos =
      {
        prometheus-targets,
        config,
        environment,
        host,
        lib,
        ...
      }:
      let
        domain = environment.getDomainFor "prometheus";
        inherit (host.settings.services.monitoring.prometheus) alerting;

        # Collected scrape targets (same-environment scoping guaranteed by
        # collect-prometheus-targets policy)
        envTargets = prometheus-targets;

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
      lib.mkMerge [
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
              useACMEHost = environment.domain;
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
        }

        (lib.mkIf (alerting != null) {
          services.prometheus = {
            alertmanagers = [ { static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ]; } ];

            rules = [
              (builtins.toJSON {
                groups = [
                  {
                    name = "fleet";
                    rules = [
                      {
                        alert = "HostDown";
                        expr = ''up{job="node"} == 0'';
                        "for" = "5m";
                        labels.severity = "critical";
                        annotations.summary = "{{ $labels.hostname }} node exporter unreachable for 5m";
                      }
                      {
                        alert = "EtcdMemberDown";
                        expr = ''up{job="etcd"} == 0'';
                        "for" = "5m";
                        labels.severity = "critical";
                        annotations.summary = "etcd on {{ $labels.hostname }} unreachable for 5m";
                      }
                    ];
                  }
                ];
              })
            ];

            alertmanager = {
              enable = true;
              listenAddress = "127.0.0.1";
              port = 9093;
              configuration = {
                global = {
                  smtp_smarthost = "${alerting.smtp.host}:${toString alerting.smtp.port}";
                  smtp_from = alerting.smtp.username;
                  smtp_auth_username = alerting.smtp.username;
                  smtp_auth_password_file = "/run/credentials/alertmanager.service/smtp-password";
                  smtp_require_tls = true;
                };
                route = {
                  receiver = "email";
                  group_by = [
                    "alertname"
                    "hostname"
                  ];
                  group_wait = "30s";
                  group_interval = "5m";
                  repeat_interval = "12h";
                };
                # A host that is down also fails its own etcd scrape.
                inhibit_rules = [
                  {
                    source_matchers = [ "alertname = HostDown" ];
                    target_matchers = [ "alertname = EtcdMemberDown" ];
                    equal = [ "hostname" ];
                  }
                ];
                receivers = [
                  {
                    name = "email";
                    email_configs = [
                      {
                        to = environment.email.adminEmail;
                        send_resolved = true;
                      }
                    ];
                  }
                ];
              };
            };
          };

          systemd.services.alertmanager.serviceConfig.LoadCredential =
            "smtp-password:${config.age.secrets.alertmanager-smtp-password.path}";
        })
      ];

    service-domains = serviceDomains;
    served-domains = { environment, host, ... }: environment.servedDomains host serviceDomains;

    age-secrets =
      { environment, host, ... }:
      let
        inherit (host.settings.services.monitoring.prometheus) alerting;
      in
      {
        age.secrets = lib.optionalAttrs (alerting != null) {
          # Read by systemd for LoadCredential, so root-owned.
          alertmanager-smtp-password.rekeyFile = environment.secretPath + "/${alerting.smtp.passwordSecret}";
        };
      };

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

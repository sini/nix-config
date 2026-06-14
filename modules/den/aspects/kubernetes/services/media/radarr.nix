# Radarr — movie PVR / library manager for the *arr stack.
#
# Postgres-backed (media-pg, radarr-main + radarr-log dbs), OIDC-protected UI via
# the gateway (AUTH__METHOD=External), fixed API key from the shared
# media-arr-api-keys secret. Mounts the shared media data PVC (/data) and the
# NFS scratch PVC (/scratch) for imports.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version pinned to 6.2.1 — latest stable LSIO release (the release in the
# media-user backup logs was 6.0.4.10291). Bump tags in a dedicated pass at
# deploy time.
{
  den.aspects.kubernetes.services.media.radarr = {
    service-domains = [ "radarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.radarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/radarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "radarr";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        images,
        ...
      }:
      let
        # Alloy River config for the per-pod log-tail sidecar. Tails Radarr's
        # ACTIVE info log only (/config/logs/radarr.txt off the config PVC
        # mounted at /config in every container; rotations radarr.N.txt and the
        # debug/trace files are intentionally excluded — Alloy follows the active
        # file across rotation by inode). Labels each entry with app/namespace +
        # a bounded static `log_file` label (the raw per-file `filename` label is
        # dropped to cap stream cardinality), parses the Servarr line format
        # (`<ts>|<LEVEL>|<Component>|<msg>`) to lift `level`, and ships to loki at
        # warn level. The duplicate main-container stdout copy is dropped at the
        # cluster DaemonSet via the den.observability/file-tailed pod label.
        #
        # CRITICAL: validate any edit with `nix run nixpkgs#grafana-alloy -- fmt`.
        logtailConfig = ''
          logging {
            level = "warn"
          }

          local.file_match "logs" {
            path_targets = [{
              "__path__"  = "/config/logs/radarr.txt",
              "app"       = "radarr",
              "namespace" = "media",
            }]
          }

          loki.source.file "logs" {
            targets    = local.file_match.logs.targets
            forward_to = [loki.process.logs.receiver]
          }

          loki.process "logs" {
            stage.regex {
              expression = "\\|(?P<level>Trace|Debug|Info|Warn|Error|Fatal)\\|"
            }

            stage.labels {
              values = {
                level = "",
              }
            }

            // Bound stream cardinality: replace the per-file `filename`
            // provenance label (one stream per rotated file) with a static
            // app-level `log_file` label, then drop the raw path.
            stage.static_labels {
              values = {
                log_file = "radarr",
              }
            }

            stage.label_drop {
              values = ["filename"]
            }

            forward_to = [loki.write.default.receiver]
          }

          loki.write "default" {
            endpoint {
              url = "http://loki.monitoring.svc:3100/loki/api/v1/push"
            }
          }
        '';
      in
      {
        applications.radarr = {
          namespace = "media";

          helm.releases.radarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Drives the cluster DaemonSet's stdout-drop for this pod's main
                # container (the logtail sidecar is the canonical log source).
                pod.labels."den.observability/file-tailed" = "true";

                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/radarr";
                    tag = "6.2.1";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    RADARR__POSTGRES__HOST = "media-pg-rw";
                    RADARR__POSTGRES__PORT = "5432";
                    RADARR__POSTGRES__MAINDB = "radarr-main";
                    RADARR__POSTGRES__LOGDB = "radarr-log";
                    RADARR__POSTGRES__USER.valueFrom.secretKeyRef = {
                      name = "media-pg-radarr-password";
                      key = "username";
                    };
                    RADARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-pg-radarr-password";
                      key = "password";
                    };
                    RADARR__AUTH__METHOD = "External";
                    RADARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "radarr";
                    };
                    # Bound /config/logs: Servarr rotates at SizeLimit MB/file
                    # keeping Rotate files (Log section; SizeLimit clamped 0..10).
                    # The file-tail sidecar ships these before they roll off.
                    RADARR__LOG__ROTATE = "2";
                    RADARR__LOG__SIZELIMIT = "1";
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 7878;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 7878;
                    };
                  };
                };

                # Prometheus metrics sidecar: scrapes the Radarr API over pod
                # loopback and re-exports it on :9707 for kube-prometheus-stack.
                containers.exportarr = {
                  image = {
                    inherit (images."onedr0p/exportarr") repository digest;
                  };
                  args = [
                    "radarr"
                    # Quiet per-scrape HTTP request logging (shipped to loki).
                    "--log-level"
                    "warn"
                  ];
                  env = {
                    PORT = "9707";
                    URL = "http://localhost:7878";
                    APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "radarr";
                    };
                  };
                  ports = [
                    {
                      name = "metrics";
                      containerPort = 9707;
                    }
                  ];
                };

                # Log-tail sidecar: tails /config/logs/radarr.txt (active info log
                # only) off the shared config PVC and ships labeled,
                # level-parsed streams to loki.
                # The grafana/alloy image entrypoint is the alloy binary, so
                # args begin with the `run` subcommand.
                containers.logtail = {
                  image = {
                    inherit (images."grafana/alloy") repository digest;
                  };
                  args = [
                    "run"
                    "/etc/alloy/config.alloy"
                    # tail offsets on the config PVC -> survive pod restart
                    "--storage.path=/config/.alloy"
                    # keep the alloy UI loopback-only (no CNP needed)
                    "--server.http.listen-addr=127.0.0.1:12345"
                  ];
                  # Must read app-written logs (LSIO writes as PUID 1027 /
                  # PGID 65536).
                  securityContext = {
                    runAsUser = 1027;
                    runAsGroup = 65536;
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 7878;
              };

              # Sidecar Alloy River config delivered as a ConfigMap.
              configMaps.logtail.data."config.alloy" = logtailConfig;

              persistence = {
                # Mount the sidecar config into the logtail container only.
                logtail = {
                  type = "configMap";
                  identifier = "logtail";
                  advancedMounts.main.logtail = [
                    {
                      path = "/etc/alloy/config.alloy";
                      subPath = "config.alloy";
                      readOnly = true;
                    }
                  ];
                };
                # MediaCover thumbnails accumulate; give the config PVC headroom.
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "5Gi";
                  storageClass = "longhorn";
                  labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                  globalMounts = [ { path = "/config"; } ];
                };
                data = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [ { path = "/data"; } ];
                };
                scratch = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-scratch-nfs";
                  globalMounts = [ { path = "/scratch"; } ];
                };
                # MediaCover on the NAS (pre-staged from the archive): bulk
                # re-fetchable artwork keyed by DB id, kept off the longhorn
                # config PVC.
                metadata = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [
                    {
                      path = "/config/MediaCover";
                      subPath = "media/metadata/radarr/MediaCover";
                    }
                  ];
                };
              };
            };
          };

          # Raw PodMonitor: no typed accessor without a kube-prometheus-stack
          # CRDs bridge, so author it directly (mirrors the monitoring aspect).
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "radarr";
                namespace = "media";
              };
              spec = {
                selector.matchLabels."app.kubernetes.io/name" = "radarr";
                podMetricsEndpoints = [
                  {
                    port = "metrics";
                    path = "/metrics";
                    interval = "30s";
                    # Default instance is the ephemeral pod IP:port, which
                    # churns on every restart; pin it to the stable app name.
                    relabelings = [
                      {
                        sourceLabels = [ "__meta_kubernetes_pod_label_app_kubernetes_io_name" ];
                        targetLabel = "instance";
                      }
                    ];
                  }
                ];
              };
            }
          ];

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-radarr.spec = {
                description = "Allow Envoy Gateway proxies to reach radarr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "radarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "7878";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-metrics-ingress-radarr.spec = {
                description = "Allow Prometheus to scrape radarr's exportarr sidecar (9707).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "radarr";
                ingress = [
                  {
                    fromEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "monitoring";
                          "app.kubernetes.io/name" = "prometheus";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "9707";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-radarr.spec = {
                description = "Allow radarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "radarr";
                egress = [
                  {
                    toEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "kube-system";
                          "k8s-app" = "kube-dns";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                          {
                            port = "53";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-postgres-egress-radarr.spec = {
                description = "Allow radarr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "radarr";
                egress = [
                  {
                    toEndpoints = [
                      { matchLabels."cnpg.io/cluster" = "media-pg"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "5432";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # World egress (80/443): movie metadata + artwork come from the
              # Servarr metadata API, a direct world call.
              allow-internet-egress-radarr.spec = {
                description = "Allow radarr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "radarr";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "80";
                            protocol = "TCP";
                          }
                          {
                            port = "443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

            httpRoutes.radarr.spec = {
              hostnames = [ (cluster.domainFor "radarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "radarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "radarr";
                      port = 7878;
                    }
                  ];
                }
              ];
            };

            securityPolicies."radarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "radarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "radarr";
                clientID = "radarr";
                clientSecret.name = "radarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.radarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.radarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

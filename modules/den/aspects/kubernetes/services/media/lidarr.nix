# Lidarr — music PVR / library manager for the *arr stack.
#
# Postgres-backed (media-pg, lidarr-main + lidarr-log dbs), OIDC-protected UI via
# the gateway (AUTH__METHOD=External), fixed API key from the shared
# media-arr-api-keys secret. Mounts the shared media data PVC (/data) and the
# NFS scratch PVC (/scratch) for imports.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version pinned to 3.1.0 — latest stable LSIO release (the release in the
# media-user backup logs was 2.14.5.4836). Bump tags in a dedicated pass at
# deploy time.
{
  den.aspects.kubernetes.services.media.lidarr = {
    service-domains = [ "lidarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.lidarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/lidarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "lidarr";
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
        # Alloy River config for the per-pod log-tail sidecar. Tails Lidarr's
        # ACTIVE info log only (/config/logs/lidarr.txt off the config PVC
        # mounted at /config in every container; rotations lidarr.N.txt and the
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
              "__path__"  = "/config/logs/lidarr.txt",
              "app"       = "lidarr",
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
                log_file = "lidarr",
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
        applications.lidarr = {
          namespace = "media";

          helm.releases.lidarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Drives the cluster DaemonSet's stdout-drop for this pod's main
                # container (the logtail sidecar is the canonical log source).
                pod.labels."den.observability/file-tailed" = "true";

                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/lidarr";
                    tag = "3.1.0";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    LIDARR__POSTGRES__HOST = "media-pg-rw";
                    LIDARR__POSTGRES__PORT = "5432";
                    LIDARR__POSTGRES__MAINDB = "lidarr-main";
                    LIDARR__POSTGRES__LOGDB = "lidarr-log";
                    LIDARR__POSTGRES__USER.valueFrom.secretKeyRef = {
                      name = "media-pg-lidarr-password";
                      key = "username";
                    };
                    LIDARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-pg-lidarr-password";
                      key = "password";
                    };
                    LIDARR__AUTH__METHOD = "External";
                    LIDARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "lidarr";
                    };
                    # Bound /config/logs: Servarr rotates at SizeLimit MB/file
                    # keeping Rotate files (Log section; SizeLimit clamped 0..10).
                    # The file-tail sidecar ships these before they roll off.
                    LIDARR__LOG__ROTATE = "2";
                    LIDARR__LOG__SIZELIMIT = "1";
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 8686;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 8686;
                    };
                  };
                };

                # Prometheus metrics sidecar: scrapes the Lidarr API over pod
                # loopback and re-exports it on :9707 for kube-prometheus-stack.
                containers.exportarr = {
                  image = {
                    inherit (images."onedr0p/exportarr") repository digest;
                  };
                  args = [
                    "lidarr"
                    # Quiet per-scrape HTTP request logging (shipped to loki).
                    "--log-level"
                    "warn"
                  ];
                  env = {
                    PORT = "9707";
                    URL = "http://localhost:8686";
                    APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "lidarr";
                    };
                  };
                  ports = [
                    {
                      name = "metrics";
                      containerPort = 9707;
                    }
                  ];
                };

                # Log-tail sidecar: tails /config/logs/lidarr.txt (active info log
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
                ports.http.port = 8686;
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
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "2Gi";
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
                      subPath = "media/metadata/lidarr/MediaCover";
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
                name = "lidarr";
                namespace = "media";
              };
              spec = {
                selector.matchLabels."app.kubernetes.io/name" = "lidarr";
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
              allow-gateway-ingress-lidarr.spec = {
                description = "Allow Envoy Gateway proxies to reach lidarr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "lidarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8686";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-metrics-ingress-lidarr.spec = {
                description = "Allow Prometheus to scrape lidarr's exportarr sidecar (9707).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "lidarr";
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

              allow-dns-egress-lidarr.spec = {
                description = "Allow lidarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "lidarr";
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

              allow-postgres-egress-lidarr.spec = {
                description = "Allow lidarr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "lidarr";
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

              # World egress (80/443): artist/album metadata + artwork come from
              # the Servarr metadata proxy (MusicBrainz front), a direct world
              # call.
              allow-internet-egress-lidarr.spec = {
                description = "Allow lidarr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "lidarr";
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

            httpRoutes.lidarr.spec = {
              hostnames = [ (cluster.domainFor "lidarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "lidarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "lidarr";
                      port = 8686;
                    }
                  ];
                  # Interactive search (anime fans out to many title-variants ×
                  # indexers, then Sonarr processes hundreds of releases) can run
                  # several minutes; 600s route timeout. The default-gateway
                  # ClientTrafficPolicy raises stream_idle_timeout to match — Envoy's
                  # 5m stream-idle default would otherwise cut the held-open response
                  # first (see envoy-gateway.nix).
                  timeouts.request = "600s";
                }
              ];
            };

            securityPolicies."lidarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "lidarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "lidarr";
                clientID = "lidarr";
                clientSecret.name = "lidarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.lidarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.lidarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

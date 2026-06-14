# Sonarr — TV series PVR / library manager for the *arr stack.
#
# Postgres-backed (media-pg, sonarr-main + sonarr-log dbs), OIDC-protected UI via
# the gateway (AUTH__METHOD=External so Sonarr trusts the gateway-authenticated
# identity), fixed API key from the shared media-arr-api-keys secret. Mounts the
# shared media data PVC (/data) and the NFS scratch PVC (/scratch) for imports.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version pinned to 4.0.17 — latest stable LSIO tag in the v4 line (the v4-era
# release in the media-user backup logs was 4.0.16.2944). Bump tags in a
# dedicated pass at deploy time.
{
  den.aspects.kubernetes.services.media.sonarr = {
    service-domains = [ "sonarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.sonarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/sonarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "sonarr";
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
        # Alloy River config for the per-pod log-tail sidecar. Tails Sonarr's
        # file logs (/config/logs/*.txt — the app PVC is mounted at /config in
        # every container), labels each entry with app/namespace + the auto
        # `filename` provenance label, parses the Servarr line format
        # (`<ts>|<LEVEL>|<Component>|<msg>`) to lift `level`, and ships to loki.
        # The duplicate main-container stdout copy is dropped at the cluster
        # DaemonSet via the den.observability/file-tailed pod label.
        #
        # CRITICAL: this River is shared-pattern config. Validate any edit with
        #   nix run nixpkgs#grafana-alloy -- fmt <file>
        logtailConfig = ''
          local.file_match "logs" {
            path_targets = [{
              "__path__"  = "/config/logs/*.txt",
              "app"       = "sonarr",
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
        applications.sonarr = {
          namespace = "media";

          helm.releases.sonarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Drives the cluster DaemonSet's stdout-drop for this pod's main
                # container (the logtail sidecar is the canonical log source).
                pod.labels."den.observability/file-tailed" = "true";

                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/sonarr";
                    tag = "4.0.17";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    SONARR__POSTGRES__HOST = "media-pg-rw";
                    SONARR__POSTGRES__PORT = "5432";
                    SONARR__POSTGRES__MAINDB = "sonarr-main";
                    SONARR__POSTGRES__LOGDB = "sonarr-log";
                    SONARR__POSTGRES__USER.valueFrom.secretKeyRef = {
                      name = "media-pg-sonarr-password";
                      key = "username";
                    };
                    SONARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-pg-sonarr-password";
                      key = "password";
                    };
                    SONARR__AUTH__METHOD = "External";
                    SONARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "sonarr";
                    };
                    # Bound /config/logs: Servarr rotates at SizeLimit MB/file
                    # keeping Rotate files. Keys verified against Sonarr source
                    # (NzbDrone.Common.Options.LogOptions: Rotate/SizeLimit under
                    # the Log section; SizeLimit clamped 0..10). The file-tail
                    # sidecar ships these before they roll off.
                    SONARR__LOG__ROTATE = "2";
                    SONARR__LOG__SIZELIMIT = "1";
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 8989;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 8989;
                    };
                  };
                };

                # Prometheus metrics sidecar: scrapes the Sonarr API over pod
                # loopback and re-exports it on :9707 for kube-prometheus-stack.
                containers.exportarr = {
                  image = {
                    inherit (images."onedr0p/exportarr") repository digest;
                  };
                  args = [ "sonarr" ];
                  env = {
                    PORT = "9707";
                    URL = "http://localhost:8989";
                    APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "sonarr";
                    };
                  };
                  ports = [
                    {
                      name = "metrics";
                      containerPort = 9707;
                    }
                  ];
                };

                # Log-tail sidecar: tails /config/logs/*.txt off the shared
                # config PVC and ships labeled, level-parsed streams to loki.
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
                ports.http.port = 8989;
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
                      subPath = "media/metadata/sonarr/MediaCover";
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
                name = "sonarr";
                namespace = "media";
              };
              spec = {
                selector.matchLabels."app.kubernetes.io/name" = "sonarr";
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
              allow-gateway-ingress-sonarr.spec = {
                description = "Allow Envoy Gateway proxies to reach sonarr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sonarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8989";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-metrics-ingress-sonarr.spec = {
                description = "Allow Prometheus to scrape sonarr's exportarr sidecar (9707).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sonarr";
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

              allow-dns-egress-sonarr.spec = {
                description = "Allow sonarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sonarr";
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

              allow-postgres-egress-sonarr.spec = {
                description = "Allow sonarr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sonarr";
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

              # World egress (80/443): series metadata + artwork come from the
              # Servarr metadata API (skyhook), a direct world call.
              allow-internet-egress-sonarr.spec = {
                description = "Allow sonarr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sonarr";
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

            httpRoutes.sonarr.spec = {
              hostnames = [ (cluster.domainFor "sonarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "sonarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "sonarr";
                      port = 8989;
                    }
                  ];
                }
              ];
            };

            securityPolicies."sonarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "sonarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "sonarr";
                clientID = "sonarr";
                clientSecret.name = "sonarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.sonarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.sonarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

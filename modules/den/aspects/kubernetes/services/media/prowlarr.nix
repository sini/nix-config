# Prowlarr — indexer manager / proxy for the *arr stack.
#
# Postgres-backed (media-pg, main+log dbs), OIDC-protected UI via the gateway
# (AUTH__METHOD=External so Prowlarr trusts the gateway-authenticated identity),
# and a fixed API key from the shared media-arr-api-keys secret so the *arrs can
# register against it deterministically.
#
# The service is described inline (formerly via the _media-app.nix mkMediaApp
# helper): a bjw-s app-template release with a longhorn config PVC, baseline
# CiliumNetworkPolicies (gateway ingress, DNS egress, media-pg egress, internet
# egress), an HTTPRoute on the default-gateway, and a Kanidm OIDC SecurityPolicy.
#
# Version pinned to 2.4.0 — latest stable LSIO release (the pre-migration
# deployment in the media-user backup logs ran 2.3.0). Bump tags in a dedicated
# pass at deploy time.
{
  den.aspects.kubernetes.services.media.prowlarr = {
    service-domains = [ "prowlarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.prowlarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/prowlarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "prowlarr";
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
        # Alloy River config for the per-pod log-tail sidecar. Tails Prowlarr's
        # file logs (/config/logs/*.txt — catches prowlarr.txt/prowlarr.N.txt +
        # prowlarr.debug.* off the config PVC mounted at /config in every
        # container), labels each entry with app/namespace + the auto `filename`
        # provenance label, parses the Servarr line format
        # (`<ts>|<LEVEL>|<Component>|<msg>`) to lift `level`, and ships to loki.
        # The duplicate main-container stdout copy is dropped at the cluster
        # DaemonSet via the den.observability/file-tailed pod label.
        #
        # CRITICAL: validate any edit with `nix run nixpkgs#grafana-alloy -- fmt`.
        logtailConfig = ''
          local.file_match "logs" {
            path_targets = [{
              "__path__"  = "/config/logs/*.txt",
              "app"       = "prowlarr",
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
        applications.prowlarr = {
          namespace = "media";

          helm.releases.prowlarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Drives the cluster DaemonSet's stdout-drop for this pod's main
                # container (the logtail sidecar is the canonical log source).
                pod.labels."den.observability/file-tailed" = "true";

                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/prowlarr";
                    tag = "2.4.0";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    "PROWLARR__POSTGRES__HOST" = "media-pg-rw";
                    "PROWLARR__POSTGRES__PORT" = "5432";
                    "PROWLARR__POSTGRES__MAINDB" = "prowlarr-main";
                    "PROWLARR__POSTGRES__LOGDB" = "prowlarr-log";
                    "PROWLARR__POSTGRES__USER".valueFrom.secretKeyRef = {
                      name = "media-pg-prowlarr-password";
                      key = "username";
                    };
                    "PROWLARR__POSTGRES__PASSWORD".valueFrom.secretKeyRef = {
                      name = "media-pg-prowlarr-password";
                      key = "password";
                    };
                    # Gateway handles authn; Prowlarr trusts it. The API key is
                    # fixed (shared secret) so downstream *arrs can register
                    # against this Prowlarr.
                    PROWLARR__AUTH__METHOD = "External";
                    PROWLARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "prowlarr";
                    };
                    # Bound /config/logs: Servarr rotates at SizeLimit MB/file
                    # keeping Rotate files (Log section; SizeLimit clamped 0..10).
                    # The file-tail sidecar ships these before they roll off.
                    PROWLARR__LOG__ROTATE = "2";
                    PROWLARR__LOG__SIZELIMIT = "1";
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 9696;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 9696;
                    };
                  };
                };

                # Prometheus metrics sidecar: scrapes the Prowlarr API over pod
                # loopback and re-exports it on :9707 for kube-prometheus-stack.
                containers.exportarr = {
                  image = {
                    inherit (images."onedr0p/exportarr") repository digest;
                  };
                  args = [ "prowlarr" ];
                  env = {
                    PORT = "9707";
                    URL = "http://localhost:9696";
                    APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "prowlarr";
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
                ports.http.port = 9696;
              };

              # Sidecar Alloy River config delivered as a ConfigMap.
              configMaps.logtail.data."config.alloy" = logtailConfig;

              # Prowlarr stores nothing on shared media/scratch — config PVC only.
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
                name = "prowlarr";
                namespace = "media";
              };
              spec = {
                selector.matchLabels."app.kubernetes.io/name" = "prowlarr";
                podMetricsEndpoints = [
                  {
                    port = "metrics";
                    path = "/metrics";
                    interval = "30s";
                  }
                ];
              };
            }
          ];

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-prowlarr.spec = {
                description = "Allow Envoy Gateway proxies to reach prowlarr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prowlarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "9696";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-metrics-ingress-prowlarr.spec = {
                description = "Allow Prometheus to scrape prowlarr's exportarr sidecar (9707).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prowlarr";
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

              allow-dns-egress-prowlarr.spec = {
                description = "Allow prowlarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prowlarr";
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

              allow-postgres-egress-prowlarr.spec = {
                description = "Allow prowlarr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prowlarr";
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

              # World egress (80/443): indexer searches + the Cardigann
              # definitions fetch are world-facing (core function; without this
              # the indexer API hangs on the definitions download and every
              # search fails).
              allow-internet-egress-prowlarr.spec = {
                description = "Allow prowlarr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prowlarr";
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

            httpRoutes.prowlarr.spec = {
              hostnames = [ (cluster.domainFor "prowlarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "prowlarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "prowlarr";
                      port = 9696;
                    }
                  ];
                }
              ];
            };

            securityPolicies."prowlarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "prowlarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "prowlarr";
                clientID = "prowlarr";
                clientSecret.name = "prowlarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.prowlarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.prowlarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

# Whisparr — adult-content PVR (Radarr fork) for the *arr stack.
#
# Uses the hotio image rather than LSIO (hotio is the maintained source for
# Whisparr). The backup config.xml shows <Branch>v2</Branch> (Whisparr v2, the
# Radarr-derived line — NOT the v3/"eros" rewrite), so the Servarr env
# convention applies and the prefix is WHISPARR__ (verified against the v2
# branding). Postgres-backed (media-pg, whisparr-main + whisparr-log dbs),
# OIDC-protected UI via the gateway, fixed API key from media-arr-api-keys.
# hotio honours PUID/PGID like LSIO.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version: archive ran v2.0.0.1750, but hotio prunes old point releases; the
# closest pinned v2 tag still published is `v2-2.2.0-release.108`. Bump in the
# dedicated tag pass at deploy time.
{
  den.aspects.kubernetes.services.media.whisparr = {
    service-domains = [ "whisparr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.whisparr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/whisparr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "whisparr";
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
        # Alloy River config for the per-pod log-tail sidecar. Tails Whisparr's
        # ACTIVE info log only (/config/logs/whisparr.txt off the config PVC
        # mounted at /config in every container; rotations whisparr.N.txt and the
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
              "__path__"  = "/config/logs/whisparr.txt",
              "app"       = "whisparr",
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
                log_file = "whisparr",
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
        applications.whisparr = {
          namespace = "media";

          helm.releases.whisparr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Drives the cluster DaemonSet's stdout-drop for this pod's main
                # container (the logtail sidecar is the canonical log source).
                pod.labels."den.observability/file-tailed" = "true";

                containers.main = {
                  image = {
                    repository = "ghcr.io/hotio/whisparr";
                    tag = "v2-2.2.0-release.108";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    WHISPARR__POSTGRES__HOST = "media-pg-rw";
                    WHISPARR__POSTGRES__PORT = "5432";
                    WHISPARR__POSTGRES__MAINDB = "whisparr-main";
                    WHISPARR__POSTGRES__LOGDB = "whisparr-log";
                    WHISPARR__POSTGRES__USER.valueFrom.secretKeyRef = {
                      name = "media-pg-whisparr-password";
                      key = "username";
                    };
                    WHISPARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-pg-whisparr-password";
                      key = "password";
                    };
                    WHISPARR__AUTH__METHOD = "External";
                    WHISPARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "whisparr";
                    };
                    # Bound /config/logs: Servarr rotates at SizeLimit MB/file
                    # keeping Rotate files (Log section; SizeLimit clamped 0..10).
                    # The file-tail sidecar ships these before they roll off.
                    WHISPARR__LOG__ROTATE = "2";
                    WHISPARR__LOG__SIZELIMIT = "1";
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 6969;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 6969;
                    };
                  };
                };

                # Log-tail sidecar: tails /config/logs/whisparr.txt (active info log
                # only) off the shared config PVC and ships labeled,
                # level-parsed streams to loki.
                # The grafana/alloy image entrypoint is the alloy binary, so
                # args begin with the `run` subcommand. (Whisparr has no metrics
                # exporter — it is log-tailed only.)
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
                  # Must read app-written logs (hotio writes as PUID 1027 /
                  # PGID 65536).
                  securityContext = {
                    runAsUser = 1027;
                    runAsGroup = 65536;
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 6969;
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
                      subPath = "media/metadata/whisparr/MediaCover";
                    }
                  ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-whisparr.spec = {
                description = "Allow Envoy Gateway proxies to reach whisparr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "whisparr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6969";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-whisparr.spec = {
                description = "Allow whisparr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "whisparr";
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

              allow-postgres-egress-whisparr.spec = {
                description = "Allow whisparr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "whisparr";
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

              # World egress (80/443): site/scene metadata + artwork come from
              # its metadata API, a direct world call.
              allow-internet-egress-whisparr.spec = {
                description = "Allow whisparr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "whisparr";
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

            httpRoutes.whisparr.spec = {
              hostnames = [ (cluster.domainFor "whisparr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "whisparr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "whisparr";
                      port = 6969;
                    }
                  ];
                  # Interactive search (anime fans out to many title-variants ×
                  # indexers, then Sonarr processes hundreds of releases) can run
                  # minutes; lift well above Envoy's 15s route default. 300s is the
                  # stream-idle ceiling — the clean max without also raising
                  # stream_idle_timeout.
                  timeouts.request = "300s";
                }
              ];
            };

            securityPolicies."whisparr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "whisparr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "whisparr";
                clientID = "whisparr";
                clientSecret.name = "whisparr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.whisparr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.whisparr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

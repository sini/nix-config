# Bazarr — subtitle manager for Sonarr/Radarr.
#
# Postgres-backed, but bazarr does NOT use the Servarr __POSTGRES__ env
# convention — it uses its own POSTGRES_* variables (verified against the backup
# config.yaml `postgresql:` block: enabled/host/port/database/username/password).
# So instead of the Servarr WHISPARR/SONARR-style env + main/log db wiring we
# supply the POSTGRES_* env explicitly, pointing at the single `bazarr` database
# with credentials from the media-pg-bazarr-password secret. The media-pg egress
# CiliumNetworkPolicy is still emitted (bazarr talks to media-pg over the same
# 5432 port as the Servarr apps).
#
# The service is described inline (formerly via the _media-app.nix mkMediaApp
# helper): a bjw-s app-template release with a longhorn config PVC, the shared
# media-data NFS mount, baseline CiliumNetworkPolicies (gateway ingress, DNS
# egress, media-pg egress, internet egress), an HTTPRoute on the default-gateway,
# and a Kanidm OIDC SecurityPolicy.
#
# Bazarr's API key lives in its config.ini (not an env var), so unlike the
# Servarr apps there is no *__AUTH__APIKEY env here. The shared
# media-arr-api-keys secret still carries a `bazarr` entry; wiring that into the
# config is left to bazarr first-boot / config seeding (Task 9/14 wire
# consumers). See report note.
#
# Version pinned to 1.5.6 — latest non-prerelease in the backup releases.txt
# (v1.5.6). LSIO publishes a matching `1.5.6` tag. Bump at deploy time.
{
  den.aspects.kubernetes.services.media.bazarr = {
    service-domains = [ "bazarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.bazarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/bazarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "bazarr";
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
        # Alloy River config for the per-pod log-tail sidecar. Bazarr writes its
        # logs to /config/log/ (singular `log` dir); we tail only the ACTIVE file
        # `bazarr.log` (the date-suffixed rotations `bazarr.log.<date>` are
        # intentionally excluded — they were the cardinality driver). Bazarr uses
        # the same pipe-delimited line format as Servarr
        # (`<ts>|<LEVEL>|<component>|<msg>`), so the same level regex applies. A
        # bounded static `log_file` label replaces the raw per-file `filename`
        # label. The duplicate main-container stdout copy is dropped at the
        # cluster DaemonSet via the den.observability/file-tailed pod label.
        #
        # Rotation: bazarr uses Python's TimedRotatingFileHandler (its own daily
        # rotation, not env-configurable) and self-prunes; Alloy follows the
        # active file across rotation by inode.
        #
        # CRITICAL: validate any edit with `nix run nixpkgs#grafana-alloy -- fmt`.
        logtailConfig = ''
          logging {
            level = "warn"
          }

          local.file_match "logs" {
            path_targets = [{
              "__path__"  = "/config/log/bazarr.log",
              "app"       = "bazarr",
              "namespace" = "media",
            }]
          }

          loki.source.file "logs" {
            targets    = local.file_match.logs.targets
            forward_to = [loki.process.logs.receiver]
          }

          loki.process "logs" {
            stage.regex {
              // Bazarr emits the level in upper case (INFO|WARNING|...) padded
              // with spaces before the pipe; match case-insensitively.
              expression = "(?i)\\|(?P<level>trace|debug|info|warn|warning|error|fatal|critical)\\s*\\|"
            }

            stage.labels {
              values = {
                level = "",
              }
            }

            // Bound stream cardinality: replace the per-file `filename`
            // provenance label (one stream per dated rotation) with a static
            // app-level `log_file` label, then drop the raw path.
            stage.static_labels {
              values = {
                log_file = "bazarr",
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
        applications.bazarr = {
          namespace = "media";

          helm.releases.bazarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Drives the cluster DaemonSet's stdout-drop for this pod's main
                # container (the logtail sidecar is the canonical log source).
                pod.labels."den.observability/file-tailed" = "true";

                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/bazarr";
                    tag = "1.5.6";
                  };
                  # Bazarr uses POSTGRES_* (not Servarr __POSTGRES__), pointing at
                  # the single `bazarr` database with media-pg-bazarr-password
                  # credentials.
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    POSTGRES_ENABLED = "true";
                    POSTGRES_HOST = "media-pg-rw";
                    POSTGRES_PORT = "5432";
                    POSTGRES_DATABASE = "bazarr";
                    POSTGRES_USERNAME.valueFrom.secretKeyRef = {
                      name = "media-pg-bazarr-password";
                      key = "username";
                    };
                    POSTGRES_PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-pg-bazarr-password";
                      key = "password";
                    };
                  };
                  envFrom = [ ];
                };

                # Log-tail sidecar: tails /config/log/bazarr.log (active) off the shared
                # config PVC and ships labeled, level-parsed streams to loki.
                # The grafana/alloy image entrypoint is the alloy binary, so
                # args begin with the `run` subcommand. (Bazarr has no metrics
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
                ports.http.port = 6767;
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
                # Bazarr reads media to write sidecar subtitles; config PVC +
                # /data only, no scratch.
                data = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [ { path = "/data"; } ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-bazarr.spec = {
                description = "Allow Envoy Gateway proxies to reach bazarr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "bazarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6767";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-bazarr.spec = {
                description = "Allow bazarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "bazarr";
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

              allow-postgres-egress-bazarr.spec = {
                description = "Allow bazarr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "bazarr";
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

              # World egress (80/443): subtitle providers (opensubtitles et al)
              # are direct world calls (core function).
              allow-internet-egress-bazarr.spec = {
                description = "Allow bazarr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "bazarr";
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

            httpRoutes.bazarr.spec = {
              hostnames = [ (cluster.domainFor "bazarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "bazarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "bazarr";
                      port = 6767;
                    }
                  ];
                }
              ];
            };

            securityPolicies."bazarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "bazarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "bazarr";
                clientID = "bazarr";
                clientSecret.name = "bazarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.bazarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.bazarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

# Komga — comics / manga / ebook server.
#
# Simple stateless-ish app: routed + OIDC-protected UI on komga.json64.dev (no
# prod.nix services.komga entry — getDomainFor falls back to <name>.<domain> =
# komga.json64.dev, which the Kanidm "komga" client already targets), clientID
# "komga".
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# == Storage ==
# Komga keeps its state (an embedded H2/SQLite database, thumbnails cache, search
# index) under /config. We give it a 2Gi longhorn config PVC. The library lives
# on the shared media NFS — comics at /data/media/comics — mounted via the shared
# media-data-nfs PVC at /data; the library root is configured in-app (Komga points
# at /data/media/comics). A plain /data mount is sufficient; no subPath gymnastics.
#
# == Auth ==
# Stack convention = Envoy Gateway OIDC only (SecurityPolicy on the HTTPRoute).
# Komga's own user store still exists (it creates an initial admin on first boot);
# we keep gateway OIDC in front and leave Komga's native auth at its default. Komga
# also supports OAuth2/OIDC natively, but we do not wire it (gateway handles it).
#
# == Networking ==
# Baseline only: DNS egress + gateway ingress. Base Komga makes minimal external
# calls (cover/metadata enrichment is the separate Komf companion, not deployed
# here), so there is no internet-egress policy. Add it later if metadata fetching
# is enabled in-app. No postgres (Komga uses its embedded DB under /config).
#
# Version: pinned to the latest stable Komga 1.x release. Bump at deploy time.
{
  den.aspects.kubernetes.services.media.komga = {
    service-domains = [ "komga" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.komga-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/komga-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "komga";
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
        # Alloy River config for the per-pod log-tail sidecar. Komga (Spring Boot
        # / logback) writes to /config/logs/komga.log; the glob `/config/logs/*.log`
        # tails the active file (rotated history is gzipped to `*.log.<date>.N.gz`
        # and intentionally not tailed). The logback line format is
        # `<ts>  <LEVEL> <pid> --- [...] : <msg>`; we lift the (upper-case) level
        # keyword. The duplicate main-container stdout copy is dropped at the
        # cluster DaemonSet via the den.observability/file-tailed pod label.
        #
        # Rotation: komga's bundled logback rolling policy rotates daily, gzips
        # history and self-prunes (maxHistory) — not env-overridable from a bundled
        # logback config, so we accept komga's default rotation.
        #
        # NB: the gotson/komga image does NOT honour PUID/PGID (it is not an LSIO
        # image); it runs as root and writes its logs + /config as uid 0. The
        # logtail sidecar therefore runs as root so it can read the logs and write
        # its offset store under /config/.alloy.
        #
        # CRITICAL: validate any edit with `nix run nixpkgs#grafana-alloy -- fmt`.
        logtailConfig = ''
          local.file_match "logs" {
            path_targets = [{
              "__path__"  = "/config/logs/*.log",
              "app"       = "komga",
              "namespace" = "media",
            }]
          }

          loki.source.file "logs" {
            targets    = local.file_match.logs.targets
            forward_to = [loki.process.logs.receiver]
          }

          loki.process "logs" {
            stage.regex {
              expression = "\\s(?P<level>TRACE|DEBUG|INFO|WARN|ERROR|FATAL)\\s"
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
        applications.komga = {
          namespace = "media";

          helm.releases.komga = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Drives the cluster DaemonSet's stdout-drop for this pod's main
                # container (the logtail sidecar is the canonical log source).
                pod.labels."den.observability/file-tailed" = "true";

                containers.main = {
                  image = {
                    repository = "ghcr.io/gotson/komga";
                    tag = "1.24.4";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                  };
                  envFrom = [ ];
                };

                # Log-tail sidecar: tails /config/logs/*.log off the shared config
                # PVC and ships labeled, level-parsed streams to loki. The
                # grafana/alloy image entrypoint is the alloy binary, so args begin
                # with the `run` subcommand. Runs as root (uid 0) because komga
                # writes its logs + /config as root (no PUID/PGID honouring).
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
                  securityContext = {
                    runAsUser = 0;
                    runAsGroup = 0;
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 25600;
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
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-komga.spec = {
                description = "Allow Envoy Gateway proxies to reach komga.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "komga";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "25600";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-komga.spec = {
                description = "Allow komga to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "komga";
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
            };

            httpRoutes.komga.spec = {
              hostnames = [ (cluster.domainFor "komga") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "komga"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "komga";
                      port = 25600;
                    }
                  ];
                }
              ];
            };

            securityPolicies."komga-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "komga";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "komga";
                clientID = "komga";
                clientSecret.name = "komga-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.komga-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.komga-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

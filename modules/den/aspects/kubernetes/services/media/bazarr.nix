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
        ...
      }:
      {
        applications.bazarr = {
          namespace = "media";

          helm.releases.bazarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
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
              };

              service.main = {
                controller = "main";
                ports.http.port = 6767;
              };

              persistence = {
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "2Gi";
                  storageClass = "longhorn";
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

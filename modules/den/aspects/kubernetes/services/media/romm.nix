# RomM — retro game ROM manager + browser.
#
# Routed + OIDC-protected UI on romm.json64.dev (no prod.nix services.romm entry —
# getDomainFor falls back to <name>.<domain> = romm.json64.dev, which the Kanidm
# "romm" client already targets), clientID "romm".
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# == DATABASE DECISION: PostgreSQL (media-pg) — confidence HIGH ==
# RomM officially supports PostgreSQL alongside MariaDB. The backend driver is
# selected with ROMM_DB_DRIVER ("postgresql" | "mariadb", default mariadb — a bare
# DB_DRIVER is silently ignored, so RomM speaks mariadb protocol to media-pg and
# crash-loops on the handshake) and the connection is given
# via DB_HOST / DB_PORT / DB_NAME / DB_USER / DB_PASSWD. We wire RomM to the shared
# media-pg CNPG cluster: the `romm` login role and `romm` database are already
# provisioned in media-pg.nix (roleApps + singleDatabases), and a generated
# password secret media-pg-romm-password already exists. So RomM needs ZERO new DB
# infrastructure — no in-pod MariaDB sidecar, no extra PVC, no extra CNP beyond the
# standard media-pg egress (postgres-egress CNP). This is the same manual-env +
# postgres-egress shape bazarr uses (RomM does not follow the Servarr __POSTGRES__
# convention, so the DB_* env is supplied explicitly).
#
# (Fallback NOT taken: a single-replica MariaDB sidecar in RomM's own pod —
# localhost:3306, one extra PVC, zero new CNPs. Unnecessary given confident
# postgres support + pre-provisioned media-pg role/db.)
#
# == Auth ==
# Stack convention = Envoy Gateway OIDC only. RomM supports native OIDC, but we
# keep the gateway SecurityPolicy in front and leave RomM's native auth at default
# (RomM still creates an internal admin user on first boot for app state). Gateway
# OIDC clientID "romm".
#
# == Storage / mounts ==
#   - library: ROMs live on the shared media NFS at /data/media/games. RomM expects
#     its library at /romm/library, so we mount the media-data-nfs PVC with subPath
#     media/games at /romm/library.
#   - state: RomM writes metadata cache (/romm/resources — can grow large), user
#     assets/saves (/romm/assets) and config (/romm/config). A single 10Gi longhorn
#     PVC is mounted at all three via subPaths (resources/assets/config). There is
#     no separate /config PVC.
#
# == Secrets ==
#   - ROMM_AUTH_SECRET_KEY: RomM's auth/credential encryption key (RomM docs:
#     `openssl rand -hex 32`). Generated via agenix `hex` generator (length 32 →
#     64 hex chars), rekeyed into a cluster sops file `media-romm` (key
#     auth-secret-key), surfaced as a k8s Secret `media-romm` and read via
#     valueFrom.secretKeyRef. Declared alongside the OIDC age-secret / k8s-manifests
#     entries inline.
#   - DB credentials: from the existing media-pg-romm-password basic-auth Secret.
#   - Metadata-provider API creds (IGDB twitch client id/secret, ScreenScraper):
#     intentionally OMITTED here — the operator adds them later via their own
#     secrets. Placeholder env names are listed (commented) below.
#
# == Networking ==
# Baseline (DNS egress + gateway ingress) + media-pg egress (postgres-egress CNP).
# RomM fetches game metadata + box art from external providers (IGDB / Twitch,
# ScreenScraper, MobyGames) once those API creds are configured, so internet egress
# (world 80/443) is allowed.
#
# Version: pinned to the latest RomM 3.x release. Bump at deploy time.
{
  den.aspects.kubernetes.services.media.romm = {
    service-domains = [ "romm" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.romm-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/romm-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "romm";
          };
        };

        # RomM auth/credential encryption key: one generated hex key (length 32 →
        # 64 hex chars), rekeyed into a cluster sops file `media-romm`.
        age.secrets.media-romm-auth-secret-key = {
          rekeyFile = environment.secretPath + "/media-romm/auth-secret-key.age";
          generator.script = "hex";
          # settings is a SECRET-level option (agenix-rekey), not generator-level
          settings.length = 32;
          sopsOutput = {
            file = "media-romm";
            key = "auth-secret-key";
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
        applications.romm = {
          namespace = "media";

          helm.releases.romm = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "rommapp/romm";
                    tag = "4.9.0-beta.3";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";

                    # --- database (media-pg, postgresql driver) ---
                    ROMM_DB_DRIVER = "postgresql";
                    DB_HOST = "media-pg-rw";
                    DB_PORT = "5432";
                    DB_NAME = "romm";
                    DB_USER.valueFrom.secretKeyRef = {
                      name = "media-pg-romm-password";
                      key = "username";
                    };
                    DB_PASSWD.valueFrom.secretKeyRef = {
                      name = "media-pg-romm-password";
                      key = "password";
                    };

                    # --- auth ---
                    ROMM_AUTH_SECRET_KEY.valueFrom.secretKeyRef = {
                      name = "media-romm";
                      key = "auth-secret-key";
                    };

                    # --- metadata provider API creds (operator-supplied later) ---
                    # IGDB_CLIENT_ID = "...";        # Twitch app client id
                    # IGDB_CLIENT_SECRET = "...";    # Twitch app client secret
                    # SCREENSCRAPER_USER = "...";
                    # SCREENSCRAPER_PASSWORD = "...";
                  };
                  envFrom = [ ];
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 8080;
              };

              persistence = {
                # ROM library: shared media NFS, subPath media/games -> /romm/library.
                library = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [
                    {
                      path = "/romm/library";
                      subPath = "media/games";
                    }
                  ];
                };

                # State: single longhorn PVC mounted at RomM's three writable dirs via
                # subPaths (resources = metadata cache, can grow large; assets = saves;
                # config = app config).
                state = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "10Gi";
                  storageClass = "longhorn";
                  globalMounts = [
                    {
                      path = "/romm/resources";
                      subPath = "resources";
                    }
                    {
                      path = "/romm/assets";
                      subPath = "assets";
                    }
                    {
                      path = "/romm/config";
                      subPath = "config";
                    }
                  ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-romm.spec = {
                description = "Allow Envoy Gateway proxies to reach romm.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "romm";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8080";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-romm.spec = {
                description = "Allow romm to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "romm";
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

              allow-postgres-egress-romm.spec = {
                description = "Allow romm to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "romm";
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

              allow-internet-egress-romm.spec = {
                description = "Allow romm to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "romm";
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

            httpRoutes.romm.spec = {
              hostnames = [ (cluster.domainFor "romm") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "romm"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "romm";
                      port = 8080;
                    }
                  ];
                }
              ];
            };

            securityPolicies."romm-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "romm";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "romm";
                clientID = "romm";
                clientSecret.name = "romm-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.romm-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.romm-oidc-client-secret.sopsRef;
            };

            # The media-romm k8s Secret (the auth key, a sops ref).
            secrets.media-romm = {
              type = "Opaque";
              stringData.auth-secret-key = config.age.secrets.media-romm-auth-secret-key.sopsRef;
            };
          };
        };
      };
  };
}

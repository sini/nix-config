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
# RomM's NATIVE OIDC (kanidm), NOT the gateway SecurityPolicy. RomM owns the OIDC
# flow itself (/api/login/openid -> kanidm -> /api/oauth/openid callback), so the
# Envoy SecurityPolicy is removed and the gateway only routes. Native OIDC buys
# per-user identity + role mapping (kanidm groups -> RomM admin/viewer via a `roles`
# claim) and leaves RomM's own API auth intact for non-interactive clients (the
# ROM-project download-cache clients can't do an interactive gateway redirect).
# clientID "romm"; admin is provisioned by media.admins membership (no first-boot
# password step). The kanidm `romm` client is a bespoke native-OIDC entry (see
# kanidm.nix) — its scopeMap also grants the `roles` scope RomM requests.
#
# == Storage / mounts ==
#   - library: VALIDATION phase — mounted at the in-flight ROM-project canonical
#     builds (media-data-nfs subPath rom-project/canonical) at /romm/library/roms,
#     read-only. RomM uses Structure A ({library}/roms/{platform}); each canonical
#     <slug> dir becomes a platform. Switch subPath to the production library +
#     drop readOnly once validated.
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
#   - Metadata-provider API creds (IGDB/Twitch client id+secret, SteamGridDB key,
#     RetroAchievements key): EXTERNALLY issued, no generator (media-vpn class).
#     Rekeyed into the cluster sops file `media-romm-metadata`, surfaced as the
#     k8s Secret of the same name. Hasheous is keyless (HASHEOUS_API_ENABLED bool).
#
# == Networking ==
# Baseline (DNS egress + gateway ingress) + media-pg egress (postgres-egress CNP).
# RomM reaches kanidm (OIDC discovery/token at idm.json64.dev) + the metadata
# providers (IGDB/Twitch, SteamGridDB, RetroAchievements, Hasheous) over the
# internet, so internet egress (world 80/443) is allowed.
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

        # Metadata-provider API credentials (IGDB/Twitch, SteamGridDB,
        # RetroAchievements) — EXTERNALLY issued by the operator, NO generator (same
        # class as the media-vpn WireGuard material). Encrypt each to the master
        # recipient, then `agenix rekey`:
        #   printf '%s' "$VALUE" | age -r "$(grep -oP 'age1\S+' .secrets/pub/master.pub)" \
        #     -o .secrets/env/prod/media-romm-metadata/<field>.age
        # (`agenix edit` works too.) Rekeyed into the cluster sops file
        # `media-romm-metadata`; the k8s Secret `media-romm-metadata` surfaces them.
        # Hasheous needs no key (HASHEOUS_API_ENABLED bool only).
        age.secrets.media-romm-metadata-igdb-client-id = {
          rekeyFile = environment.secretPath + "/media-romm-metadata/igdb-client-id.age";
          sopsOutput = {
            file = "media-romm-metadata";
            key = "igdb-client-id";
          };
        };
        age.secrets.media-romm-metadata-igdb-client-secret = {
          rekeyFile = environment.secretPath + "/media-romm-metadata/igdb-client-secret.age";
          sopsOutput = {
            file = "media-romm-metadata";
            key = "igdb-client-secret";
          };
        };
        age.secrets.media-romm-metadata-steamgriddb-api-key = {
          rekeyFile = environment.secretPath + "/media-romm-metadata/steamgriddb-api-key.age";
          sopsOutput = {
            file = "media-romm-metadata";
            key = "steamgriddb-api-key";
          };
        };
        age.secrets.media-romm-metadata-retroachievements-api-key = {
          rekeyFile = environment.secretPath + "/media-romm-metadata/retroachievements-api-key.age";
          sopsOutput = {
            file = "media-romm-metadata";
            key = "retroachievements-api-key";
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

                    # --- native OIDC (kanidm); replaces the gateway SecurityPolicy ---
                    OIDC_ENABLED = "true";
                    OIDC_AUTOLOGIN = "true";
                    OIDC_PROVIDER = "kanidm"; # display label only (login page / heartbeat)
                    OIDC_CLIENT_ID = "romm";
                    OIDC_CLIENT_SECRET.valueFrom.secretKeyRef = {
                      name = "romm-oidc-client-secret";
                      key = "client-secret";
                    };
                    OIDC_REDIRECT_URI = "https://${cluster.domainFor "romm"}/api/oauth/openid";
                    OIDC_SERVER_APPLICATION_URL = "https://${cluster.domainFor "romm"}";
                    OIDC_SERVER_METADATA_URL = "${cluster.secrets.oidcIssuerFor "romm"}/.well-known/openid-configuration";
                    # kanidm emits a `roles` claim (claimMaps.roles): media.admins ->
                    # admin, media.access -> user. RomM ALSO requests `roles` as a scope
                    # (scope = "openid profile email ${OIDC_CLAIM_ROLES}"), so the kanidm
                    # romm client must grant `roles` in its scopeMap (see kanidm.nix).
                    OIDC_CLAIM_ROLES = "roles";
                    OIDC_ROLE_ADMIN = "admin";
                    OIDC_ROLE_VIEWER = "user";

                    # --- metadata providers ---
                    # RomM's recommended optimal combo: Hasheous + IGDB +
                    # SteamGridDB + RetroAchievements. Hasheous is a keyless public
                    # hash-matching service (bool toggle); the other three take
                    # externally-issued creds from the media-romm-metadata Secret.
                    HASHEOUS_API_ENABLED = "true";
                    IGDB_CLIENT_ID.valueFrom.secretKeyRef = {
                      name = "media-romm-metadata";
                      key = "igdb-client-id";
                    };
                    IGDB_CLIENT_SECRET.valueFrom.secretKeyRef = {
                      name = "media-romm-metadata";
                      key = "igdb-client-secret";
                    };
                    STEAMGRIDDB_API_KEY.valueFrom.secretKeyRef = {
                      name = "media-romm-metadata";
                      key = "steamgriddb-api-key";
                    };
                    RETROACHIEVEMENTS_API_KEY.valueFrom.secretKeyRef = {
                      name = "media-romm-metadata";
                      key = "retroachievements-api-key";
                    };
                  };
                  envFrom = [ ];
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 8080;
              };

              persistence = {
                # VALIDATION: point at the in-flight ROM-project canonical builds on
                # the same NAS volume (media-data-nfs = vault:/volume2/data), read-only
                # so RomM scans/identifies but never writes/moves the canonical tree.
                # Mounted at /romm/library/roms so each <slug> dir becomes a RomM
                # platform (Structure A = {library}/roms/{platform_fs_slug}). After
                # validation, flip subPath back to the production library + drop readOnly.
                library = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [
                    {
                      path = "/romm/library/roms";
                      subPath = "rom-project/canonical";
                      readOnly = true;
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
                  labels."recurring-job-group.longhorn.io/media-config" = "enabled";
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

            # No Envoy SecurityPolicy: RomM authenticates via its NATIVE OIDC (env
            # above). The gateway just routes; the romm-oidc-client-secret Secret is
            # now consumed by RomM's OIDC_CLIENT_SECRET env, not a SecurityPolicy.
            secrets.romm-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.romm-oidc-client-secret.sopsRef;
            };

            # The media-romm k8s Secret (the auth key, a sops ref).
            secrets.media-romm = {
              type = "Opaque";
              stringData.auth-secret-key = config.age.secrets.media-romm-auth-secret-key.sopsRef;
            };

            # Metadata-provider API creds (sops refs; populated via agenix — see
            # the age-secrets block). IGDB needs both id + secret; SteamGridDB and
            # RetroAchievements one key each. Hasheous is keyless.
            secrets.media-romm-metadata = {
              type = "Opaque";
              stringData = {
                igdb-client-id = config.age.secrets.media-romm-metadata-igdb-client-id.sopsRef;
                igdb-client-secret = config.age.secrets.media-romm-metadata-igdb-client-secret.sopsRef;
                steamgriddb-api-key = config.age.secrets.media-romm-metadata-steamgriddb-api-key.sopsRef;
                retroachievements-api-key =
                  config.age.secrets.media-romm-metadata-retroachievements-api-key.sopsRef;
              };
            };
          };
        };
      };
  };
}

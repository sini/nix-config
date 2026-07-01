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
#   - resources: RomM's metadata cache (/romm/resources — covers/screenshots from
#     the providers, grows large + is fully regenerable on rescan). On the NAS
#     (media-data-nfs, RWX) under rom-project/romm-metadata/resources, writable. Not
#     a DB (the DB is media-pg postgres), so NFS is safe, and the NAS is the durable
#     bulk tier — no reason to spend replicated block storage on a regenerable cache.
#   - userdata: user-generated state that is NOT regenerable — savegames / save
#     states / uploaded assets (/romm/assets) and config.yml (/romm/config). KEPT on
#     a replicated longhorn block PVC (romm-userdata) so it is replicated across
#     nodes + enrolled in the media-config nightly backup job. Over-provisioned to
#     20Gi (longhorn is thin-provisioned — actual disk = data written, not the
#     nominal request) so savestates never run out.
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

        # Redis/valkey password (generated, strong alnum). Same media-romm sops
        # file. Run `agenix generate` to create the .age after this lands.
        age.secrets.media-romm-redis-password = {
          rekeyFile = environment.secretPath + "/media-romm/redis-password.age";
          generator.script = "alnum";
          sopsOutput = {
            file = "media-romm";
            key = "redis-password";
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
      let
        # Tunable scan/scale knobs (romm-settings.nix; per-cluster overrides in the
        # cluster's `settings.kubernetes.services.media.romm.*`).
        inherit (cluster.settings.kubernetes.services.media.romm)
          scanTimeout
          scanWorkers
          replicas
          ;
      in
      {
        applications.romm = {
          namespace = "media";

          helm.releases.romm = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                # Replica count is a cluster setting. NOTE: extra replicas do NOT
                # speed a single scan (that is SCAN_WORKERS below); see
                # romm-settings.nix for the RWO-userdata caveat before raising it.
                inherit replicas;
                containers.main = {
                  image = {
                    repository = "rommapp/romm";
                    tag = "4.9.0-beta.3";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";

                    # --- scanning (cluster-tunable; see romm-settings.nix) ---
                    # SCAN_TIMEOUT caps a single scan job; SCAN_WORKERS is the
                    # asyncio concurrency over per-ROM metadata I/O (the real
                    # throughput lever — default 1 scans strictly serially).
                    SCAN_TIMEOUT = toString scanTimeout;
                    SCAN_WORKERS = toString scanWorkers;

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

                    # --- setup wizard: disabled. RomM's frontend otherwise gates the
                    # ENTIRE SPA behind the first-run wizard until an admin row exists
                    # (SHOW_SETUP_WIZARD = admin-count==0 AND not DISABLE_SETUP_WIZARD),
                    # and the OIDC autologin redirect can't get past that gate. With it
                    # off, the first media.admins OIDC login provisions the admin (RomM
                    # creates the user as ADMIN from the roles claim) — no local wizard
                    # account, fully OIDC-native. ---
                    DISABLE_SETUP_WIZARD = "true";

                    # --- redis/valkey: RomM uses it for sessions + the RQ task queue
                    # (scans) + cache. Dedicated romm-redis service (below), auth from
                    # the generated media-romm/redis-password. Without REDIS_HOST RomM
                    # defaults to 127.0.0.1:6379 (nothing there) and runs degraded. ---
                    REDIS_HOST = "romm-redis";
                    REDIS_PORT = "6379";
                    REDIS_PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-romm";
                      key = "redis-password";
                    };

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
                    # Firmware/BIOS: RomM (Structure A) serves firmware from
                    # {library}/bios/{platform_fs_slug}. The bios tree is hash-built +
                    # verified against RomM's known_bios_files reference; slugs already
                    # equal RomM fs_slugs. Same NAS volume, read-only.
                    {
                      path = "/romm/library/bios";
                      subPath = "rom-project/bios";
                      readOnly = true;
                    }
                  ];
                };

                # Metadata cache (resources): bulky + regenerable → on the NAS
                # (media-data-nfs, RWX), writable, beside the read-only canonical
                # library on the same volume. subPath under rom-project/romm-metadata.
                resources = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [
                    {
                      path = "/romm/resources";
                      subPath = "rom-project/romm-metadata/resources";
                    }
                  ];
                };

                # User-generated state (savegames / save states / uploaded assets +
                # config.yml): NOT regenerable → kept on the small replicated longhorn
                # block PVC romm-userdata (defined under resources below; replicated +
                # backed up via the media-config job).
                userdata = {
                  type = "persistentVolumeClaim";
                  existingClaim = "romm-userdata";
                  globalMounts = [
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

          # Dedicated valkey for RomM (sessions + RQ task queue + cache), via the
          # official valkey chart (charts/valkey/valkey). Standalone Deployment, ACL
          # auth: the `default` user's password is read from media-romm/redis-password
          # (the same Secret romm reads via REDIS_PASSWORD). Ephemeral — a pure cache;
          # sessions/queue rebuild on restart. fullnameOverride pins the Service name
          # to romm-redis (= romm's REDIS_HOST).
          helm.releases.romm-redis = {
            chart = charts.valkey.valkey;
            values = {
              fullnameOverride = "romm-redis";
              auth = {
                enabled = true;
                usersExistingSecret = "media-romm";
                aclUsers.default = {
                  permissions = "~* &* +@all";
                  passwordKey = "redis-password";
                };
              };
              persistence.enabled = false;
              service.port = 6379;
            };
          };

          resources = {
            # Replicated longhorn PVC for RomM's non-regenerable user state
            # (savegames / save states / uploaded assets + config.yml). The bulky
            # regenerable metadata cache lives on the NAS instead (see persistence
            # above). Over-provisioned to 20Gi so savestates never run out: longhorn
            # is thin-provisioned, so actual replicated disk = data written, not this
            # nominal request. The media-config label enrolls it in the nightly
            # off-cluster backup recurring job. (PVCs auto-namespace to media.)
            persistentVolumeClaims.romm-userdata = {
              metadata.labels."recurring-job-group.longhorn.io/media-config" = "enabled";
              spec = {
                accessModes = [ "ReadWriteOnce" ];
                storageClassName = "longhorn";
                resources.requests.storage = "20Gi";
              };
            };

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

              # romm -> romm-redis (valkey) for sessions/queue/cache. The valkey
              # chart labels its pods app.kubernetes.io/instance=romm-redis
              # (name=valkey), so select on the instance label.
              allow-redis-egress-romm.spec = {
                description = "Allow romm to reach its valkey (romm-redis).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "romm";
                egress = [
                  {
                    toEndpoints = [
                      { matchLabels."app.kubernetes.io/instance" = "romm-redis"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6379";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # romm-redis only accepts traffic from romm (on 6379).
              allow-romm-ingress-redis.spec = {
                description = "Allow romm to reach the romm-redis valkey.";
                endpointSelector.matchLabels."app.kubernetes.io/instance" = "romm-redis";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "romm"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6379";
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

            # The media-romm k8s Secret (auth key + redis password, sops refs).
            secrets.media-romm = {
              type = "Opaque";
              stringData = {
                auth-secret-key = config.age.secrets.media-romm-auth-secret-key.sopsRef;
                redis-password = config.age.secrets.media-romm-redis-password.sopsRef;
              };
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

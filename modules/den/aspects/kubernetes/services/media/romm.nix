# RomM — retro game ROM manager + browser.
#
# Routed + OIDC-protected UI on romm.json64.dev (no prod.nix services.romm entry —
# getDomainFor falls back to <name>.<domain> = romm.json64.dev, which the Kanidm
# "romm" client already targets), clientID "romm".
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
# standard media-pg egress (postgresCnp = true). This is the same manual-env +
# postgresCnp shape bazarr uses (RomM does not follow the Servarr __POSTGRES__
# convention, so postgres = false and the DB_* env is supplied explicitly).
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
#     media/games at /romm/library (explicit persistence entry in extraValues,
#     instead of the helper's whole-/data mount).
#   - state: RomM writes metadata cache (/romm/resources — can grow large), user
#     assets/saves (/romm/assets) and config (/romm/config). A single 10Gi longhorn
#     config PVC is mounted at all three via subPaths (resources/assets/config).
#     config-size = null on the helper so it does not also mount a /config PVC.
#
# == Secrets ==
#   - ROMM_AUTH_SECRET_KEY: RomM's auth/credential encryption key (RomM docs:
#     `openssl rand -hex 32`). Generated via agenix `hex` generator (length 32 →
#     64 hex chars), rekeyed into a cluster sops file `media-romm` (key
#     auth-secret-key), surfaced as a k8s Secret `media-romm` and read via
#     valueFrom.secretKeyRef. Post-merged onto the helper's OIDC age-secrets /
#     k8s-manifests (the qbittorrent media-vpn pattern), so the helper's OIDC
#     entries are preserved.
#   - DB credentials: from the existing media-pg-romm-password basic-auth Secret.
#   - Metadata-provider API creds (IGDB twitch client id/secret, ScreenScraper):
#     intentionally OMITTED here — the operator adds them later via their own
#     secrets. Placeholder env names are listed (commented) below.
#
# == Networking ==
# Helper baseline (DNS egress + gateway ingress) + media-pg egress (postgresCnp).
# RomM fetches game metadata + box art from external providers (IGDB / Twitch,
# ScreenScraper, MobyGames) once those API creds are configured, so internetEgress
# = true (world 80/443).
#
# Version: pinned to the latest RomM 3.x release. Bump at deploy time.
{
  config,
  lib,
  ...
}:
let
  media-app = import ./_media-app.nix { inherit lib; };

  rommPort = 8080;

  # Auth secret: one generated hex key, rekeyed into a cluster sops file
  # `media-romm`. The .age file is created by `agenix generate` after this lands.
  authSecretName = "media-romm";
  authAgeName = "media-romm-auth-secret-key";
  authSopsKey = "auth-secret-key";

  app = media-app.mkMediaApp {
    name = "romm";
    port = rommPort;
    image = {
      repository = "rommapp/romm";
      tag = "4.9.0-beta.3";
    };
    inherit (config.den) environments;

    # RomM uses DB_* (not the Servarr __POSTGRES__ convention); wire it manually
    # below and re-enable the media-pg egress policy via postgresCnp.
    postgres = false;
    postgresCnp = true;

    # State PVC is defined explicitly in extraValues (mounted at three /romm
    # subPaths), so the helper must not also mount a /config PVC.
    config-size = null;

    # Library mount is explicit (subPath media/games -> /romm/library) in
    # extraValues; do not use the helper's whole-/data mount.
    mounts = { };

    # RomM fetches metadata + cover art from external providers (IGDB/Twitch,
    # ScreenScraper) once API creds are configured.
    internetEgress = true;

    env = {
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
        name = authSecretName;
        key = authSopsKey;
      };

      # --- metadata provider API creds (operator-supplied later) ---
      # IGDB_CLIENT_ID = "...";        # Twitch app client id
      # IGDB_CLIENT_SECRET = "...";    # Twitch app client secret
      # SCREENSCRAPER_USER = "...";
      # SCREENSCRAPER_PASSWORD = "...";
    };

    extraValues = {
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
in
{
  den.aspects.kubernetes.services.media.romm = app // {
    # Post-merge the generated auth-secret age entry onto the helper's OIDC
    # age-secrets (recursiveUpdate so the OIDC entry is preserved).
    age-secrets =
      args@{ cluster, ... }:
      let
        environment = config.den.environments.${cluster.environment};
      in
      lib.recursiveUpdate (app.age-secrets args) {
        age.secrets.${authAgeName} = {
          rekeyFile = environment.secretPath + "/media-romm/auth-secret-key.age";
          generator.script = "hex";
          # settings is a SECRET-level option (agenix-rekey), not generator-level
          settings.length = 32;
          sopsOutput = {
            file = authSecretName;
            key = authSopsKey;
          };
        };
      };

    # Post-merge the media-romm k8s Secret (the auth key, a sops ref) onto the
    # helper's application manifests. Formals must cover everything the helper's
    # k8s-manifests needs (config, cluster, charts) — forwarded verbatim.
    k8s-manifests =
      args@{
        config,
        cluster,
        charts,
        ...
      }:
      lib.recursiveUpdate (app.k8s-manifests args) {
        applications.romm.resources.secrets.${authSecretName} = {
          type = "Opaque";
          stringData.${authSopsKey} = config.age.secrets.${authAgeName}.sopsRef;
        };
      };
  };
}

# Bazarr — subtitle manager for Sonarr/Radarr.
#
# Postgres-backed, but bazarr does NOT use the Servarr __POSTGRES__ env
# convention — it uses its own POSTGRES_* variables (verified against the backup
# config.yaml `postgresql:` block: enabled/host/port/database/username/password).
# So we pass `postgres = false` (to suppress the helper's WHISPARR/SONARR-style
# env + main/log db wiring) and instead supply the POSTGRES_* env explicitly,
# pointing at the single `bazarr` database with credentials from the
# media-pg-bazarr-password secret. `postgresCnp = true` re-enables the media-pg
# egress CiliumNetworkPolicy that `postgres` would normally bring (the smallest
# helper extension; documented in _media-app.nix).
#
# Bazarr's API key lives in its config.ini (not an env var), so unlike the
# Servarr apps there is no *__AUTH__APIKEY env here. The shared
# media-arr-api-keys secret still carries a `bazarr` entry; wiring that into the
# config is left to bazarr first-boot / config seeding (Task 9/14 wire
# consumers). See report note.
#
# Version pinned to 1.5.6 — latest non-prerelease in the backup releases.txt
# (v1.5.6). LSIO publishes a matching `1.5.6` tag. Bump at deploy time.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };
in
{
  den.aspects.kubernetes.services.media.bazarr = media-app.mkMediaApp {
    name = "bazarr";
    port = 6767;
    image = {
      repository = "lscr.io/linuxserver/bazarr";
      tag = "1.5.6";
    };
    inherit (config.den) environments;

    # Bazarr uses POSTGRES_* (not Servarr __POSTGRES__); wire it manually below
    # and re-enable the media-pg egress policy via postgresCnp.
    postgres = false;
    postgresCnp = true;

    config-size = "2Gi";

    env = {
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

    # Bazarr reads media to write sidecar subtitles; config PVC + /data only,
    # no scratch.
    mounts = {
      data = true;
    };

    # World egress (80/443): subtitle providers (opensubtitles et al) are direct world calls
    # (core function).
    internetEgress = true;

    # Bazarr serves its health/UI on the web port; no Servarr /ping endpoint.
  };
}

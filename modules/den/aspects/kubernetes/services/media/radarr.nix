# Radarr — movie PVR / library manager for the *arr stack.
#
# Postgres-backed (media-pg, radarr-main + radarr-log dbs), OIDC-protected UI via
# the gateway (AUTH__METHOD=External), fixed API key from the shared
# media-arr-api-keys secret. Mounts the shared media data PVC (/data) and the
# NFS scratch PVC (/scratch) for imports.
#
# Version pinned to 6.2.1 — latest stable LSIO release (the release in the
# media-user backup logs was 6.0.4.10291). Bump tags in a dedicated pass at
# deploy time.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };
in
{
  den.aspects.kubernetes.services.media.radarr = media-app.mkMediaApp {
    name = "radarr";
    port = 7878;
    image = {
      repository = "lscr.io/linuxserver/radarr";
      tag = "6.2.1";
    };
    inherit (config.den) environments;

    postgres = true;

    # MediaCover thumbnails accumulate; give the config PVC headroom.
    config-size = "5Gi";

    env = {
      RADARR__AUTH__METHOD = "External";
      RADARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
        name = "media-arr-api-keys";
        key = "radarr";
      };
    };

    mounts = {
      data = true;
      scratch-nfs = true;
      # MediaCover on the NAS (pre-staged from the archive) — see _media-app.nix.
      metadata = true;
    };

    # World egress (80/443): movie metadata + artwork come from the Servarr metadata API, a
    # direct world call.
    internetEgress = true;

    # Servarr HTTP health endpoint.
    extraValues.controllers.main.containers.main.probes = {
      liveness = {
        enabled = true;
        type = "HTTP";
        path = "/ping";
        port = 7878;
      };
      readiness = {
        enabled = true;
        type = "HTTP";
        path = "/ping";
        port = 7878;
      };
    };
  };
}

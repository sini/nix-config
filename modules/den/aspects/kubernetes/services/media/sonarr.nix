# Sonarr — TV series PVR / library manager for the *arr stack.
#
# Postgres-backed (media-pg, sonarr-main + sonarr-log dbs), OIDC-protected UI via
# the gateway (AUTH__METHOD=External so Sonarr trusts the gateway-authenticated
# identity), fixed API key from the shared media-arr-api-keys secret. Mounts the
# shared media data PVC (/data) and the NFS scratch PVC (/scratch) for imports.
#
# Version pinned to 4.0.17 — latest stable LSIO tag in the v4 line (the v4-era
# release in the media-user backup logs was 4.0.16.2944). Bump tags in a
# dedicated pass at deploy time.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };
in
{
  den.aspects.kubernetes.services.media.sonarr = media-app.mkMediaApp {
    name = "sonarr";
    port = 8989;
    image = {
      repository = "lscr.io/linuxserver/sonarr";
      tag = "4.0.17";
    };
    inherit (config.den) environments;

    postgres = true;

    # MediaCover thumbnails accumulate; give the config PVC headroom.
    config-size = "5Gi";

    env = {
      SONARR__AUTH__METHOD = "External";
      SONARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
        name = "media-arr-api-keys";
        key = "sonarr";
      };
    };

    mounts = {
      data = true;
      scratch-nfs = true;
    };

    # Servarr HTTP health endpoint.
    extraValues.controllers.main.containers.main.probes = {
      liveness = {
        enabled = true;
        type = "HTTP";
        path = "/ping";
        port = 8989;
      };
      readiness = {
        enabled = true;
        type = "HTTP";
        path = "/ping";
        port = 8989;
      };
    };
  };
}

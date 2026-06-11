# Lidarr — music PVR / library manager for the *arr stack.
#
# Postgres-backed (media-pg, lidarr-main + lidarr-log dbs), OIDC-protected UI via
# the gateway (AUTH__METHOD=External), fixed API key from the shared
# media-arr-api-keys secret. Mounts the shared media data PVC (/data) and the
# NFS scratch PVC (/scratch) for imports.
#
# Version pinned to 2.14.5 — the release found running in the media-user backup
# logs (latest entry v2.14.5.4836). LSIO publishes a matching `2.14.5` tag. Bump
# tags in a dedicated pass at deploy time.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };
in
{
  den.aspects.kubernetes.services.media.lidarr = media-app.mkMediaApp {
    name = "lidarr";
    port = 8686;
    image = {
      repository = "lscr.io/linuxserver/lidarr";
      tag = "2.14.5";
    };
    inherit (config.den) environments;

    postgres = true;

    config-size = "2Gi";

    env = {
      LIDARR__AUTH__METHOD = "External";
      LIDARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
        name = "media-arr-api-keys";
        key = "lidarr";
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
        port = 8686;
      };
      readiness = {
        enabled = true;
        type = "HTTP";
        path = "/ping";
        port = 8686;
      };
    };
  };
}

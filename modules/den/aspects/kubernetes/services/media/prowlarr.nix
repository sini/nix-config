# Prowlarr — indexer manager / proxy for the *arr stack.
#
# Postgres-backed (media-pg, main+log dbs), OIDC-protected UI via the gateway
# (AUTH__METHOD=External so Prowlarr trusts the gateway-authenticated identity),
# and a fixed API key from the shared media-arr-api-keys secret so the *arrs can
# register against it deterministically.
#
# Version pinned to 2.4.0 — latest stable LSIO release (the pre-migration
# deployment in the media-user backup logs ran 2.3.0). Bump tags in a dedicated
# pass at deploy time.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };
in
{
  den.aspects.kubernetes.services.media.prowlarr = media-app.mkMediaApp {
    name = "prowlarr";
    port = 9696;
    image = {
      repository = "lscr.io/linuxserver/prowlarr";
      tag = "2.4.0";
    };
    inherit (config.den) environments;

    postgres = true;

    # Gateway handles authn; Prowlarr trusts it. The API key is fixed (shared
    # secret) so downstream *arrs can register against this Prowlarr.
    env = {
      PROWLARR__AUTH__METHOD = "External";
      PROWLARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
        name = "media-arr-api-keys";
        key = "prowlarr";
      };
    };

    # Prowlarr stores nothing on shared media/scratch — config PVC only.
    mounts = { };

    # World egress (80/443): indexer searches + the Cardigann definitions fetch are world-facing
    # (core function; without this the indexer API hangs on the definitions
    # download and every search fails).
    internetEgress = true;

    # Servarr HTTP health endpoint.
    extraValues.controllers.main.containers.main.probes = {
      liveness = {
        enabled = true;
        type = "HTTP";
        path = "/ping";
        port = 9696;
      };
      readiness = {
        enabled = true;
        type = "HTTP";
        path = "/ping";
        port = 9696;
      };
    };
  };
}

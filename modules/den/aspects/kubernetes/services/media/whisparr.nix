# Whisparr — adult-content PVR (Radarr fork) for the *arr stack.
#
# Uses the hotio image rather than LSIO (hotio is the maintained source for
# Whisparr). The backup config.xml shows <Branch>v2</Branch> (Whisparr v2, the
# Radarr-derived line — NOT the v3/"eros" rewrite), so the Servarr env
# convention applies and the prefix is WHISPARR__ (verified against the v2
# branding). Postgres-backed (media-pg, whisparr-main + whisparr-log dbs),
# OIDC-protected UI via the gateway, fixed API key from media-arr-api-keys.
# hotio honours PUID/PGID like LSIO.
#
# Version: archive ran v2.0.0.1750, but hotio prunes old point releases; the
# closest pinned v2 tag still published is `v2-2.2.0-release.108`. Bump in the
# dedicated tag pass at deploy time.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };
in
{
  den.aspects.kubernetes.services.media.whisparr = media-app.mkMediaApp {
    name = "whisparr";
    port = 6969;
    image = {
      repository = "ghcr.io/hotio/whisparr";
      tag = "v2-2.2.0-release.108";
    };
    inherit (config.den) environments;

    postgres = true;

    config-size = "2Gi";

    env = {
      WHISPARR__AUTH__METHOD = "External";
      WHISPARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
        name = "media-arr-api-keys";
        key = "whisparr";
      };
    };

    mounts = {
      data = true;
      scratch-nfs = true;
      # MediaCover on the NAS (pre-staged from the archive) — see _media-app.nix.
      metadata = true;
    };

    # Servarr HTTP health endpoint.
    extraValues.controllers.main.containers.main.probes = {
      liveness = {
        enabled = true;
        type = "HTTP";
        path = "/ping";
        port = 6969;
      };
      readiness = {
        enabled = true;
        type = "HTTP";
        path = "/ping";
        port = 6969;
      };
    };
  };
}

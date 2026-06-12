# Shoko — AniDB-backed anime cataloging server.
#
# Complements the sonarr anime lane: sonarr acquires, shoko catalogs against
# AniDB IDs (and feeds Shokofin-style consumers later). Official image (not
# LSIO): config lives at /home/shoko/.shoko, so the config PVC mount path is
# overridden; PUID/PGID are honored. Mounts the shared media data PVC for
# import folders (configured in-app under /data).
#
# AniDB talks over its own ports: UDP API on 9000, HTTP API on 9001 —
# world egress for those rides an extra CNP next to the standard 80/443
# (artwork CDN) policy.
#
# Version pinned to v5.3.3 — latest stable. Bump in a dedicated pass.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };
in
{
  den.aspects.kubernetes.services.media.shoko = media-app.mkMediaApp {
    name = "shoko";
    port = 8111;
    image = {
      repository = "shokoanime/server";
      tag = "v5.3.3";
    };
    inherit (config.den) environments;

    # AniDB image cache + database grow with the collection.
    config-size = "10Gi";

    mounts.data = true;

    # Artwork/banner CDNs over HTTPS.
    internetEgress = true;

    extraCnps = {
      allow-anidb-egress-shoko.spec = {
        description = "Allow shoko to reach the AniDB UDP (9000) and HTTP (9001) APIs.";
        endpointSelector.matchLabels."app.kubernetes.io/name" = "shoko";
        egress = [
          {
            toEntities = [ "world" ];
            toPorts = [
              {
                ports = [
                  {
                    port = "9000";
                    protocol = "UDP";
                  }
                  {
                    port = "9001";
                    protocol = "TCP";
                  }
                ];
              }
            ];
          }
        ];
      };
    };

    extraValues = {
      # Official image keeps its state in /home/shoko/.shoko (no /config).
      persistence.config.globalMounts = [ { path = "/home/shoko/.shoko"; } ];

      controllers.main.containers.main.probes = {
        liveness = {
          enabled = true;
          type = "HTTP";
          path = "/api/v3/Init/Status";
          port = 8111;
        };
        readiness = {
          enabled = true;
          type = "HTTP";
          path = "/api/v3/Init/Status";
          port = 8111;
        };
      };
    };
  };
}

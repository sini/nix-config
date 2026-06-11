# Unpackerr — extracts completed (rar/zip) downloads for the *arr stack.
#
# No web UI: route = false, oidc = false. Unpackerr is stateless (config comes
# entirely from env), so config-size = null (no /config PVC). The helper always
# emits a Service, so we keep its metrics/healthcheck port 5656; with route =
# false no HTTPRoute/SecurityPolicy is created, so the Service is harmless and we
# avoid a helper change.
#
# Storage: scratch-local RWO → /scratch, co-scheduling Unpackerr onto the same
# node (axon-01) as qBittorrent/SABnzbd so it can see the completed torrents on
# local disk and extract them in place.
#
# Wiring (from the backup compose arr.yaml, minus the retired readarr): one
# instance block per *arr, pointing at the in-namespace short service name
# (sonarr/radarr/lidarr/whisparr resolve inside ns `media`) with the fixed API
# key from the shared media-arr-api-keys secret. Watch path is the completed
# torrents dir on the local scratch volume.
#
# Networking: the helper emits DNS egress only. Unpackerr's own egress edges —
# to each *arr API port — are added here in-file (named
# allow-arr-egress-unpackerr). These are Unpackerr's edges from the cross-service
# matrix; the policy-matrix task (Task 9) owns the *inbound* side on the *arrs.
#
# Version: hotio prunes old point releases and the backup carries no version
# marker, so we pin to the latest stable golift release (0.15.2). Bump at deploy time.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };

  completePath = "/scratch/torrents/complete";

  apiKey = key: {
    valueFrom.secretKeyRef = {
      name = "media-arr-api-keys";
      inherit key;
    };
  };

  # One env block per *arr instance (index 0).
  arrEnv = prefix: key: url: {
    "UN_${prefix}_0_URL" = url;
    "UN_${prefix}_0_API_KEY" = apiKey key;
    "UN_${prefix}_0_PATHS_0" = completePath;
  };

  # Egress edge to a single *arr service port.
  arrEgress = svc: port: {
    toEndpoints = [
      { matchLabels."app.kubernetes.io/name" = svc; }
    ];
    toPorts = [
      {
        ports = [
          {
            port = toString port;
            protocol = "TCP";
          }
        ];
      }
    ];
  };
in
{
  den.aspects.kubernetes.services.media.unpackerr = media-app.mkMediaApp {
    name = "unpackerr";
    port = 5656;
    image = {
      repository = "golift/unpackerr";
      tag = "0.15.2";
    };
    inherit (config.den) environments;

    postgres = false;

    # Stateless — env-only, no /config PVC.
    config-size = null;

    # No UI to route or protect.
    route = false;
    oidc = false;

    # Sees the same completed-torrents view as qBittorrent on the scratch node.
    mounts = {
      scratch-local = true;
    };

    env = {
      UN_LOG_QUEUES = "1m";
    }
    // arrEnv "SONARR" "sonarr" "http://sonarr:8989"
    // arrEnv "RADARR" "radarr" "http://radarr:7878"
    // arrEnv "LIDARR" "lidarr" "http://lidarr:8686"
    // arrEnv "WHISPARR" "whisparr" "http://whisparr:6969";

    # Unpackerr's own egress to the four *arr APIs (in addition to the helper's
    # DNS egress). Inbound isolation on the *arrs is owned by the policy matrix.
    extraCnps."allow-arr-egress-unpackerr".spec = {
      description = "Allow unpackerr to reach the *arr APIs (sonarr/radarr/lidarr/whisparr).";
      endpointSelector.matchLabels."app.kubernetes.io/name" = "unpackerr";
      egress = [
        (arrEgress "sonarr" 8989)
        (arrEgress "radarr" 7878)
        (arrEgress "lidarr" 8686)
        (arrEgress "whisparr" 6969)
      ];
    };
  };
}

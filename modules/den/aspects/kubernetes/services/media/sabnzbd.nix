# SABnzbd — Usenet (NZB) download client for the media stack.
#
# Routed + OIDC-protected UI on nzb.json64.dev (NOT the default
# sabnzbd.json64.dev): the helper derives the hostname from
# `getDomainFor "sabnzbd"`, so prod.nix declares
# `services.sabnzbd.domain = "nzb.json64.dev"` and the helper picks it up with
# zero helper changes. The OIDC clientID stays "sabnzbd".
#
# Storage: scratch-local ONLY (RWO `media-scratch-local` PVC → /scratch). The
# RWO claim co-schedules SABnzbd onto the same node (axon-01) as the other
# scratch-local pods (qBittorrent), keeping completed downloads on fast local
# disk. SAB writes its work under /scratch/usenet/{incomplete,complete}; it has
# NO /data mount — the *arrs import from the NFS scratch view, not from SAB.
#
# API key: SAB reads its key from sabnzbd.ini, not from env. We seed the ini via
# an init container (controllers.main.initContainers.config-seed) that, on a
# fresh /config, writes a minimal ini wiring the api_key from the shared
# media-arr-api-keys secret (so the *arrs can register against SAB
# deterministically) + host_whitelist + the /scratch download dirs; on an
# existing /config it rewrites the api_key and ensures host_whitelist. The
# script is idempotent. See the inline script for every ini key touched.
#
# Networking: besides the helper's gateway-ingress + DNS-egress baselines, SAB
# needs world egress to Usenet providers (NNTP 119 / NNTPS 563) and to indexers
# / SSL providers (443). The helper's `internetEgress` flag only opens 80/443,
# so we add the NNTP ports through `extraEgressPorts` (the one sanctioned helper
# extension for this task; documented in _media-app.nix).
#
# Version: the media-user backup carries no SABnzbd version marker (the ini has
# no version field), so we pin to the latest stable LSIO tag (5.0.4) rather than
# `latest`. Bump tags in the dedicated deploy-time pass.
{ config, lib, ... }:
let
  media-app = import ./_media-app.nix { inherit lib; };

  # Minimal sabnzbd.ini seeder. Idempotent:
  #   fresh /config  -> write a minimal [misc] section
  #   existing       -> rewrite api_key + ensure host_whitelist line
  # ini keys touched (all under [misc]):
  #   api_key        — fixed key from media-arr-api-keys/sabnzbd (env API_KEY)
  #   host_whitelist — nzb.json64.dev (+ in-cluster short name `sabnzbd`) so SAB
  #                    accepts the proxied Host header from the gateway
  #   host/port      — bind all interfaces on 8080
  #   download_dir   — /scratch/usenet/incomplete
  #   complete_dir   — /scratch/usenet/complete
  # printf (not a heredoc) so this survives Nix indented-string dedenting — no
  # column-0 sensitivity.
  configSeedScript = ''
    set -eu
    INI=/config/sabnzbd.ini
    WHITELIST="nzb.json64.dev, sabnzbd"
    mkdir -p /scratch/usenet/incomplete /scratch/usenet/complete
    if [ ! -f "$INI" ]; then
      echo "seeding fresh $INI"
      {
        printf '%s\n' '[misc]'
        printf '%s\n' 'host = 0.0.0.0'
        printf '%s\n' 'port = 8080'
        printf '%s\n' "api_key = $API_KEY"
        printf '%s\n' "host_whitelist = $WHITELIST"
        printf '%s\n' 'download_dir = /scratch/usenet/incomplete'
        printf '%s\n' 'complete_dir = /scratch/usenet/complete'
      } > "$INI"
    else
      echo "reconciling existing $INI"
      # sed "/^\[misc\]/a ..." silently no-ops if [misc] is absent (set -e can't
      # catch it), so ensure the section exists before any append below.
      grep -q '^\[misc\]' "$INI" || printf '[misc]\n' >> "$INI"
      if grep -q '^api_key = ' "$INI"; then
        sed -i "s|^api_key = .*|api_key = $API_KEY|" "$INI"
      else
        sed -i "/^\[misc\]/a api_key = $API_KEY" "$INI"
      fi
      if grep -q '^host_whitelist = ' "$INI"; then
        sed -i "s|^host_whitelist = .*|host_whitelist = $WHITELIST|" "$INI"
      else
        sed -i "/^\[misc\]/a host_whitelist = $WHITELIST" "$INI"
      fi
    fi
  '';
in
{
  den.aspects.kubernetes.services.media.sabnzbd = media-app.mkMediaApp {
    name = "sabnzbd";
    port = 8080;
    image = {
      repository = "lscr.io/linuxserver/sabnzbd";
      tag = "5.0.4";
    };
    inherit (config.den) environments;

    # SAB stores nothing in postgres.
    postgres = false;

    config-size = "1Gi";

    # scratch-local RWO → /scratch (pins pod to the scratch node). No /data.
    mounts = {
      scratch-local = true;
    };

    # World egress on 80/443 (indexers / SSL providers) plus the NNTP ports SAB
    # needs to reach Usenet providers.
    internetEgress = true;
    extraEgressPorts = [
      "119"
      "563"
    ];

    extraValues = {
      controllers.main = {
        # Seed/reconcile sabnzbd.ini before the main container starts. Runs the
        # SAB image (same UID handling) so /config ownership stays consistent.
        initContainers.config-seed = {
          image = {
            repository = "lscr.io/linuxserver/sabnzbd";
            tag = "5.0.4";
          };
          command = [
            "/bin/sh"
            "-c"
            configSeedScript
          ];
          env.API_KEY.valueFrom.secretKeyRef = {
            name = "media-arr-api-keys";
            key = "sabnzbd";
          };
        };

        # SAB serves its UI on the web port; default probe is fine.
        containers.main.probes = {
          liveness = {
            enabled = true;
            type = "HTTP";
            path = "/";
            port = 8080;
          };
          readiness = {
            enabled = true;
            type = "HTTP";
            path = "/";
            port = 8080;
          };
        };
      };
    };
  };
}

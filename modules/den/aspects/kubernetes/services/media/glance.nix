# Glance — the primary at-a-glance media dashboard.
#
# A simple stateless web app (single binary, YAML config). Built via the
# mkMediaApp helper: routed + OIDC-protected UI on glance.json64.dev (no prod.nix
# services.glance entry — getDomainFor falls back to <name>.<domain> =
# glance.json64.dev, which the Kanidm "glance" client already targets), clientID
# "glance".
#
# == Config ==
# Glance reads /app/config/glance.yml. We deliver it as a ConfigMap mounted as a
# single file via subPath (the recyclarr.nix pattern), so there is NO config PVC
# (config-size = null). The starter config is minimal-but-real:
#   - Home page: clock, calendar, an RSS placeholder feed.
#   - Media page: a `monitor` widget pinging every in-cluster *arr + downloader on
#     its short service name, plus Jellyfin on its external URL; and a bookmarks
#     group linking each media UI's public hostname.
# Glance's monitor widget is an HTTP liveness ping (GET, status check) — it needs
# NO API keys, only network reachability. Full personalisation (RSS feeds,
# markets, weather, video subs) is layered in post-deploy per user preference.
#
# == Networking ==
# Egress (matching the pre-declared dashboard ingress edges in network-policy.nix:
# glance is an allowed ingress source on the *arr API ports + sabnzbd):
#   - DNS + gateway-ingress: helper baseline.
#   - in-namespace API edges to sonarr/radarr/lidarr/whisparr/sabnzbd — emitted
#     here as extraCnps (the egress mirror of the pre-declared ingress allows).
#     prowlarr/qbittorrent are intentionally excluded: prowlarr is not surfaced on
#     the dashboard (no pre-declared ingress for it) and qbittorrent is owned by
#     qbittorrent.nix / surfaced via the *arrs' download clients.
#   - internet egress (80/443): glance monitors Jellyfin on its external URL
#     (jellyfin.json64.dev, served off uplink — outside the cluster) and fetches
#     icon assets (si: simple-icons) from a CDN. internetEgress = true covers both.
#
# Version: pinned to the latest stable glance release. Bump at deploy time.
{
  config,
  lib,
  ...
}:
let
  media-app = import ./_media-app.nix { inherit lib; };

  glancePort = 8080;

  # In-namespace service ports glance monitors (the dashboard ingress edges
  # pre-declared in network-policy.nix). Single source of truth for the egress
  # policy + the monitor widget URLs below.
  monitorTargets = {
    sonarr = 8989;
    radarr = 7878;
    lidarr = 8686;
    whisparr = 6969;
    sabnzbd = 8080;
  };

  podSelector.matchLabels."app.kubernetes.io/name" = "glance";

  # Egress allow to one in-namespace service on its TCP port.
  apiEgress = svc: port: {
    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = svc; } ];
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

  # Starter glance.yml. Catppuccin Mocha theme (mined from the old config). The
  # monitor widget pings in-cluster short service names over HTTP; Jellyfin uses
  # its external HTTPS URL. No API keys — monitor is a liveness ping only.
  glanceYml = ''
    theme:
      # Catppuccin Mocha
      background-color: 240 21 15
      contrast-multiplier: 1.2
      primary-color: 217 92 83
      positive-color: 115 54 76
      negative-color: 347 70 65

    pages:
      - name: Home
        columns:
          - size: small
            widgets:
              - type: clock
                hour-format: 12h
              - type: calendar
                first-day-of-week: monday
          - size: full
            widgets:
              - type: rss
                limit: 10
                collapse-after: 3
                cache: 12h
                feeds:
                  - url: https://selfh.st/rss/
                    title: selfh.st

      - name: Media
        columns:
          - size: full
            widgets:
              - type: monitor
                cache: 1m
                title: Media Services
                sites:
                  - title: Sonarr
                    url: http://sonarr:8989/
                    icon: si:sonarr
                  - title: Radarr
                    url: http://radarr:7878/
                    icon: si:radarr
                  - title: Lidarr
                    url: http://lidarr:8686/
                    icon: si:lidarr
                  - title: Whisparr
                    url: http://whisparr:6969/
                    icon: si:w
                  - title: SABnzbd
                    url: http://sabnzbd:8080/
                    icon: si:sabnzbd
                  - title: Jellyfin
                    url: https://jellyfin.json64.dev/
                    icon: si:jellyfin
          - size: small
            widgets:
              - type: bookmarks
                groups:
                  - title: Media UIs
                    links:
                      - title: Jellyfin
                        url: https://jellyfin.json64.dev/
                      - title: Sonarr
                        url: https://sonarr.json64.dev/
                      - title: Radarr
                        url: https://radarr.json64.dev/
                      - title: Lidarr
                        url: https://lidarr.json64.dev/
                      - title: Whisparr
                        url: https://whisparr.json64.dev/
                      - title: Prowlarr
                        url: https://prowlarr.json64.dev/
                      - title: Bazarr
                        url: https://bazarr.json64.dev/
                      - title: SABnzbd
                        url: https://nzb.json64.dev/
                      - title: qBittorrent
                        url: https://torrent.json64.dev/
  '';

  app = media-app.mkMediaApp {
    name = "glance";
    port = glancePort;
    image = {
      repository = "glanceapp/glance";
      tag = "v0.8.5";
    };
    inherit (config.den) environments;

    # Stateless: config arrives via ConfigMap (below), no config PVC.
    config-size = null;

    # Glance monitors Jellyfin's external URL + fetches simple-icons from a CDN.
    internetEgress = true;

    # Egress mirror of the pre-declared dashboard ingress edges: glance -> each
    # monitored in-namespace service on its API port.
    extraCnps = {
      "allow-api-egress-glance".spec = {
        description = "Allow glance to reach the in-namespace media APIs it monitors.";
        endpointSelector = podSelector;
        egress = lib.mapAttrsToList apiEgress monitorTargets;
      };
    };

    # glance.yml delivered as a ConfigMap, mounted as a single file at
    # /app/config/glance.yml via subPath. The image's default command already
    # reads /app/config/glance.yml, so no args override is needed.
    extraValues = {
      configMaps.config.data."glance.yml" = glanceYml;

      persistence.config = {
        type = "configMap";
        identifier = "config";
        globalMounts = [
          {
            path = "/app/config/glance.yml";
            subPath = "glance.yml";
            readOnly = true;
          }
        ];
      };
    };
  };
in
{
  den.aspects.kubernetes.services.media.glance = app;
}

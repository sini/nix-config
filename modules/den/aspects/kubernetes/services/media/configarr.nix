# Configarr — syncs TRaSH-Guides quality definitions / profiles into the *arr
# instances on a schedule. Successor to recyclarr.nix — an independent tool
# that consumes Recyclarr's config-templates and additionally adds
# experimental support for Lidarr & Whisparr, so one aspect covers all four
# arrs.
#
# Not a long-running service (no UI, no Service, no route): a daily CronJob. The
# mkMediaApp helper assumes deployment + service + route, so configarr is a raw
# aspect that drives the bjw-s app-template chart directly with a `cronjob`
# controller.
#
# Config: a ConfigMap (config.yml) is mounted at /app/config/config.yml — the
# documented container config path. The API keys are NOT baked into the YAML —
# configarr supports the `!env` YAML tag, and the docs explicitly recommend it
# for Kubernetes (keys come straight from a k8s Secret as env). So the keys
# arrive as SONARR_API_KEY / RADARR_API_KEY / LIDARR_API_KEY / WHISPARR_API_KEY
# env from the shared media-arr-api-keys secret. base_url points at the
# in-namespace short service names (sonarr/radarr/lidarr/whisparr resolve in ns
# `media`). We deliberately do NOT render a secrets.yml file — `!env` is the
# recommended container path and avoids a second secret representation.
#
# Repo cache: configarr git-clones the TRaSH-Guides + recyclarr-config repos
# into /app/repos on each run. For a CronJob this is ephemeral, so we mount an
# emptyDir there: each run re-clones from scratch (a few MB over HTTPS).
# Tradeoff: no cross-run cache, slightly slower + a fresh fetch each midnight;
# acceptable for a once-daily job and avoids provisioning a PVC for a transient
# pod. (The upstream k8s example uses a PVC for persistence; we opt out.)
#
# The starter config is intentionally minimal-but-real: it syncs the
# quality-definition (series/movie) for Sonarr/Radarr plus the matching
# TRaSH quality-definition template. Lidarr/Whisparr get a conservative,
# experimental block (base_url + api_key only — quality_definition presets are
# "not evaluated" for those arrs per the configarr docs). Full TRaSH
# custom-format / quality-profile templates are layered in post-deploy per user
# preference.
#
# Networking: DNS egress + egress to all four arrs + world 443 (configarr
# fetches the TRaSH guides + recyclarr config templates from GitHub on each
# run). Emitted as plain CiliumNetworkPolicies here (raw aspect, no helper
# baselines). The ingress default-deny lockdown lives in network-policy.nix
# (the media policy matrix), alongside the other route-less helpers.
#
# Version: pinned to the latest stable configarr release (1.28.0). Bump at
# deploy time.
{ ... }:
let
  schedule = "0 0 * * *"; # daily at midnight (cluster TZ via env TZ)

  # Minimal-but-real starter config. `!env` pulls each key from the env we wire
  # below from the shared media-arr-api-keys secret. quality_definition sync is
  # the safe, always-applicable baseline for Sonarr/Radarr.
  #
  # Lidarr/Whisparr are EXPERIMENTAL in configarr: their quality_definition
  # presets are not evaluated and no TRaSH/recyclarr presets exist, so we keep
  # them to base_url + api_key only (a valid, no-op-but-connected baseline) and
  # layer real config in via local templates post-deploy.
  configYml = ''
    # Explicit upstream template sources (defaults, pinned for clarity).
    trashGuideUrl: https://github.com/TRaSH-Guides/Guides
    recyclarrConfigUrl: https://github.com/recyclarr/config-templates

    sonarr:
      series:
        base_url: http://sonarr:8989
        api_key: !env SONARR_API_KEY
        quality_definition:
          type: series
        include:
          - template: sonarr-quality-definition-series

    radarr:
      movies:
        base_url: http://radarr:7878
        api_key: !env RADARR_API_KEY
        quality_definition:
          type: movie
        include:
          - template: radarr-quality-definition-movie

    # experimental support (configarr Lidarr v2): conservative baseline only.
    lidarr:
      main:
        base_url: http://lidarr:8686
        api_key: !env LIDARR_API_KEY

    # experimental support (configarr Whisparr v3): conservative baseline only.
    whisparr:
      main:
        base_url: http://whisparr:6969
        api_key: !env WHISPARR_API_KEY
  '';

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

  podSelector.matchLabels."app.kubernetes.io/name" = "configarr";
in
{
  den.aspects.kubernetes.services.media.configarr = {
    k8s-manifests =
      { charts, ... }:
      {
        applications.configarr = {
          namespace = "media";

          helm.releases.configarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.configarr = {
                type = "cronjob";
                cronjob = {
                  inherit schedule;
                  concurrencyPolicy = "Forbid";
                  successfulJobsHistory = 3;
                  failedJobsHistory = 3;
                };
                containers.main = {
                  image = {
                    repository = "ghcr.io/raydak-labs/configarr";
                    tag = "1.28.0";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    SONARR_API_KEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "sonarr";
                    };
                    RADARR_API_KEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "radarr";
                    };
                    LIDARR_API_KEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "lidarr";
                    };
                    WHISPARR_API_KEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "whisparr";
                    };
                  };
                };
              };

              # config.yml delivered as a ConfigMap, mounted as a single file
              # at /app/config/config.yml (the documented container path) via
              # subPath.
              configMaps.config.data."config.yml" = configYml;

              persistence = {
                config = {
                  type = "configMap";
                  identifier = "config";
                  globalMounts = [
                    {
                      path = "/app/config/config.yml";
                      subPath = "config.yml";
                      readOnly = true;
                    }
                  ];
                };

                # Ephemeral repo cache: configarr re-clones the TRaSH +
                # recyclarr-config repos here on each run. emptyDir is fine for
                # a once-daily CronJob (no cross-run persistence needed).
                repos = {
                  type = "emptyDir";
                  globalMounts = [ { path = "/app/repos"; } ];
                };
              };
            };
          };

          resources.ciliumNetworkPolicies = {
            "allow-dns-egress-configarr".spec = {
              description = "Allow configarr to resolve via kube-dns.";
              endpointSelector = podSelector;
              egress = [
                {
                  toEndpoints = [
                    {
                      matchLabels = {
                        "k8s:io.kubernetes.pod.namespace" = "kube-system";
                        "k8s-app" = "kube-dns";
                      };
                    }
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "53";
                          protocol = "UDP";
                        }
                        {
                          port = "53";
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };

            "allow-arr-egress-configarr".spec = {
              description = "Allow configarr to reach the sonarr/radarr/lidarr/whisparr APIs.";
              endpointSelector = podSelector;
              egress = [
                (arrEgress "sonarr" 8989)
                (arrEgress "radarr" 7878)
                (arrEgress "lidarr" 8686)
                (arrEgress "whisparr" 6969)
              ];
            };

            "allow-internet-egress-configarr".spec = {
              description = "Allow configarr to fetch the TRaSH/recyclarr config templates over HTTPS.";
              endpointSelector = podSelector;
              egress = [
                {
                  toEntities = [ "world" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "443";
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };
          };
        };
      };
  };
}

# SUPERSEDED — replaced by configarr.nix.
#
# This aspect is NOT included from clusters/axon.nix anymore. configarr.nix
# (an independent tool that consumes Recyclarr's config-templates) does
# everything this did AND adds Lidarr/Whisparr, covering all four arrs in one
# aspect. Kept here for reference only; do not re-add it to the cluster
# include list — both CronJobs would sync sonarr/radarr concurrently with
# divergent results.
#
# ---------------------------------------------------------------------------
#
# Recyclarr — syncs TRaSH-Guides quality definitions / profiles into Sonarr &
# Radarr on a schedule.
#
# Not a long-running service (no UI, no Service, no route): a daily CronJob. The
# mkMediaApp helper assumes deployment + service + route, so recyclarr is a raw
# aspect that drives the bjw-s app-template chart directly with a `cronjob`
# controller.
#
# Config: a ConfigMap (recyclarr.yml) is mounted at /config/recyclarr.yml. The
# API keys are NOT baked into the YAML — recyclarr supports `!env_var`
# substitution, so the keys arrive as SONARR_API_KEY / RADARR_API_KEY env from
# the shared media-arr-api-keys secret. base_url points at the in-namespace short
# service names (sonarr/radarr resolve inside ns `media`).
#
# The starter config is intentionally minimal-but-real: it syncs the
# quality-definition (series/movie) for each instance. Full TRaSH custom-format /
# quality-profile templates are layered in post-deploy per user preference.
#
# Networking: DNS egress + egress to sonarr/radarr + world 443 (recyclarr fetches
# the TRaSH guides from GitHub on each run). Emitted as plain
# CiliumNetworkPolicies here (raw aspect, no helper baselines).
#
# Version: pinned to the latest stable recyclarr release (8.6.0). Bump at deploy time.
{ ... }:
let
  schedule = "0 0 * * *"; # daily at midnight (cluster TZ via env TZ)

  # Minimal-but-real starter config. !env_var pulls the key from the env we wire
  # below. quality_definition sync is the safe, always-applicable baseline.
  recyclarrYml = ''
    sonarr:
      series:
        base_url: http://sonarr:8989
        api_key: !env_var SONARR_API_KEY
        quality_definition:
          type: series

    radarr:
      movies:
        base_url: http://radarr:7878
        api_key: !env_var RADARR_API_KEY
        quality_definition:
          type: movie
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

  podSelector.matchLabels."app.kubernetes.io/name" = "recyclarr";
in
{
  den.aspects.kubernetes.services.media.recyclarr = {
    k8s-manifests =
      { charts, ... }:
      {
        applications.recyclarr = {
          namespace = "media";

          helm.releases.recyclarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.recyclarr = {
                type = "cronjob";
                cronjob = {
                  inherit schedule;
                  concurrencyPolicy = "Forbid";
                  successfulJobsHistory = 3;
                  failedJobsHistory = 3;
                };
                containers.main = {
                  image = {
                    repository = "ghcr.io/recyclarr/recyclarr";
                    tag = "8.6.0";
                  };
                  # `sync` applies every configured instance.
                  args = [ "sync" ];
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
                  };
                };
              };

              # recyclarr.yml delivered as a ConfigMap, mounted as a single file
              # at /config/recyclarr.yml via subPath.
              configMaps.config.data."recyclarr.yml" = recyclarrYml;

              persistence.config = {
                type = "configMap";
                identifier = "config";
                globalMounts = [
                  {
                    path = "/config/recyclarr.yml";
                    subPath = "recyclarr.yml";
                    readOnly = true;
                  }
                ];
              };
            };
          };

          resources.ciliumNetworkPolicies = {
            "allow-dns-egress-recyclarr".spec = {
              description = "Allow recyclarr to resolve via kube-dns.";
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

            "allow-arr-egress-recyclarr".spec = {
              description = "Allow recyclarr to reach the sonarr/radarr APIs.";
              endpointSelector = podSelector;
              egress = [
                (arrEgress "sonarr" 8989)
                (arrEgress "radarr" 7878)
              ];
            };

            "allow-internet-egress-recyclarr".spec = {
              description = "Allow recyclarr to fetch the TRaSH guides over HTTPS.";
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

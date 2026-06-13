# Unpackerr — extracts completed (rar/zip) downloads for the *arr stack.
#
# No web UI: route = false, oidc = false. Unpackerr is stateless (config comes
# entirely from env), so there is no /config PVC. We still emit a Service on the
# metrics/healthcheck port 5656; with no route there is no HTTPRoute /
# SecurityPolicy, so the Service is harmless.
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
# Networking: the DNS-egress baseline plus Unpackerr's own egress edges — to
# each *arr API port — added in-file (allow-arr-egress-unpackerr). These are
# Unpackerr's edges from the cross-service matrix; the policy-matrix task
# (Task 9) owns the *inbound* side on the *arrs.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version: hotio prunes old point releases and the backup carries no version
# marker, so we pin to the latest stable golift release (0.15.2). Bump at deploy time.
{
  den.aspects.kubernetes.services.media.unpackerr = {
    service-domains = [ ];

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        ...
      }:
      let
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
        applications.unpackerr = {
          namespace = "media";

          helm.releases.unpackerr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "golift/unpackerr";
                    tag = "0.15.2";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    UN_LOG_QUEUES = "1m";
                  }
                  // arrEnv "SONARR" "sonarr" "http://sonarr:8989"
                  // arrEnv "RADARR" "radarr" "http://radarr:7878"
                  // arrEnv "LIDARR" "lidarr" "http://lidarr:8686"
                  // arrEnv "WHISPARR" "whisparr" "http://whisparr:6969";
                  envFrom = [ ];
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 5656;
              };

              persistence = {
                # Sees the same completed-torrents view as qBittorrent on the
                # scratch node. No /config PVC (env-only config).
                scratch = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-scratch-local";
                  globalMounts = [ { path = "/scratch"; } ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-dns-egress-unpackerr.spec = {
                description = "Allow unpackerr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "unpackerr";
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

              # Unpackerr's own egress to the four *arr APIs (in addition to the
              # DNS egress). Inbound isolation on the *arrs is owned by the policy
              # matrix.
              allow-arr-egress-unpackerr.spec = {
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
          };
        };
      };
  };
}

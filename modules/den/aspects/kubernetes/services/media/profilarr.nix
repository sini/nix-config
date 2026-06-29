# Profilarr — Sonarr/Radarr quality-profile + custom-format sync tool (the
# Dictionarry database). Replaces the configarr CronJob: a long-running web app
# that OWNS its profile + arr-connection state in a SQLite DB on a longhorn
# /config PVC (backed up off-cluster via the media-config recurring-job group).
# It pushes to the arrs from its own UI/scheduler — NOT a k8s CronJob.
#
# Modeled on the routed-app template (radarr.nix), MINUS: postgres (Profilarr is
# SQLite-only — no external-DB option, the komga precedent), the media-library
# mounts (it only talks to arr APIs), the exportarr metrics sidecar (no /metrics
# exists), and the logtail sidecar (logs aren't Servarr-format — stdout flows to
# Loki via the cluster DaemonSet, the romm pattern; note: no `level` parsing).
#
# AUTH=off → Profilarr trusts the gateway-authenticated identity (the Servarr
# External model); the Envoy SecurityPolicy OIDC is the sole gate. Arr
# connections (sonarr/radarr only — Dictionarry doesn't drive lidarr/whisparr)
# are entered in the UI post-deploy: Profilarr's public API is unshipped
# (upstream #401), so that slice is not yet declarative (PVC-backed instead).
#
# ndots:1 dnsConfig: Profilarr git-clones the Dictionarry database from github on
# each sync. Like configarr, its git stalls resolving github.com under the
# cluster default ndots:5 — ndots:1 resolves single-dot github.com as absolute
# while 0-dot service names (sonarr/radarr) still use the search list.
#
# Version pinned to v2.0.9 — bump in the media tag-bump pass at deploy time.
{
  den.aspects.kubernetes.services.media.profilarr = {
    service-domains = [ "profilarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.profilarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/profilarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "profilarr";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        ...
      }:
      let
        # Egress edge to a single *arr service port (mirrors configarr.nix).
        arrEgress = svc: port: {
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

        podSelector.matchLabels."app.kubernetes.io/name" = "profilarr";
      in
      {
        applications.profilarr = {
          namespace = "media";

          helm.releases.profilarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              # See header: ndots:1 unblocks the Dictionarry github clone.
              defaultPodOptions.dnsConfig.options = [
                {
                  name = "ndots";
                  value = "1";
                }
              ];

              controllers.main = {
                type = "deployment";

                containers.main = {
                  image = {
                    repository = "ghcr.io/dictionarry-hub/profilarr";
                    tag = "v2.0.9";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    # Gateway OIDC is the sole gate (Servarr External model).
                    AUTH = "off";
                    # External origin for CSRF / reverse-proxy correctness.
                    ORIGIN = "https://${cluster.domainFor "profilarr"}";
                  };
                  # Profilarr has no documented HTTP health path; TCP/6868.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "TCP";
                      port = 6868;
                    };
                    readiness = {
                      enabled = true;
                      type = "TCP";
                      port = 6868;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 6868;
              };

              # SQLite DB + cloned git repos. longhorn RWO; the media-config label
              # enrolls this fresh PVC in the off-cluster NAS backup group.
              persistence.config = {
                type = "persistentVolumeClaim";
                accessMode = "ReadWriteOnce";
                size = "2Gi";
                storageClass = "longhorn";
                labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                globalMounts = [ { path = "/config"; } ];
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-profilarr.spec = {
                description = "Allow Envoy Gateway proxies to reach profilarr.";
                endpointSelector = podSelector;
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6868";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-profilarr.spec = {
                description = "Allow profilarr to resolve via kube-dns.";
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

              # sonarr/radarr only — Dictionarry does not drive lidarr/whisparr.
              allow-arr-egress-profilarr.spec = {
                description = "Allow profilarr to reach the sonarr/radarr APIs.";
                endpointSelector = podSelector;
                egress = [
                  (arrEgress "sonarr" 8989)
                  (arrEgress "radarr" 7878)
                ];
              };

              allow-internet-egress-profilarr.spec = {
                description = "Allow profilarr to git-clone the Dictionarry database over HTTPS.";
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

            httpRoutes.profilarr.spec = {
              hostnames = [ (cluster.domainFor "profilarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "profilarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "profilarr";
                      port = 6868;
                    }
                  ];
                  # No custom timeout: Profilarr does no slow interactive search
                  # (cf. komga/romm). Envoy's 15s route default applies.
                }
              ];
            };

            securityPolicies."profilarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "profilarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "profilarr";
                clientID = "profilarr";
                clientSecret.name = "profilarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.profilarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.profilarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

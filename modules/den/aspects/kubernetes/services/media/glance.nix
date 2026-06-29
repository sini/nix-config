# Glance — the primary at-a-glance media dashboard.
#
# A simple stateless web app (single binary, YAML config). Routed + OIDC-protected
# UI on the gateway (clientID "glance"; cluster.domainFor "glance" → glance.<domain>).
#
# == Config ==
# Glance reads /app/config/glance.yml. Delivered as a ConfigMap mounted as a single
# file via subPath, so there is NO config PVC. The starter config is
# minimal-but-real: a Home page (clock/calendar/RSS) and a Media page (a `monitor`
# widget pinging every in-cluster *arr + downloader, plus Jellyfin on its external
# URL; and a bookmarks group linking each media UI's public hostname). The monitor
# widget is an HTTP liveness ping — no API keys, only network reachability.
#
# == Networking ==
#   - DNS + gateway-ingress baseline.
#   - in-namespace API egress to the monitored services (the egress mirror of the
#     dashboard ingress allows in network-policy.nix).
#   - internet egress (80/443): glance monitors Jellyfin's external URL and fetches
#     simple-icons from a CDN.
#
# Version: pinned to the latest stable glance release. Bump at deploy time.
{
  den.aspects.kubernetes.services.media.glance = {
    service-domains = [ "glance" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.glance-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/glance-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "glance";
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
      {
        applications.glance = {
          namespace = "media";

          helm.releases.glance = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "glanceapp/glance";
                    tag = "v0.8.5";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 8080;
              };

              # glance.yml delivered as a ConfigMap, mounted as a single file at
              # /app/config/glance.yml via subPath. The image's default command
              # already reads that path, so no args override is needed. Catppuccin
              # Mocha theme; the monitor widget pings in-cluster short service names
              # over HTTP and Jellyfin on its external HTTPS URL (no API keys).
              configMaps.config.data."glance.yml" = ''
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

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-glance.spec = {
                description = "Allow Envoy Gateway proxies to reach glance.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "glance";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8080";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-glance.spec = {
                description = "Allow glance to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "glance";
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

              allow-internet-egress-glance.spec = {
                description = "Allow glance to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "glance";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "80";
                            protocol = "TCP";
                          }
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

              allow-api-egress-glance.spec = {
                description = "Allow glance to reach the in-namespace media APIs it monitors.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "glance";
                egress = [
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "lidarr"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8686";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "radarr"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "7878";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "sabnzbd"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8080";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "sonarr"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8989";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "whisparr"; } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6969";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

            httpRoutes.glance.spec = {
              hostnames = [ (cluster.domainFor "glance") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "glance"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "glance";
                      port = 8080;
                    }
                  ];
                }
              ];
            };

            securityPolicies."glance-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "glance";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "glance";
                clientID = "glance";
                clientSecret.name = "glance-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.glance-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.glance-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

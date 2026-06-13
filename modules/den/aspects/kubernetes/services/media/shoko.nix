# Shoko — AniDB-backed anime cataloging server.
#
# Complements the sonarr anime lane: sonarr acquires, shoko catalogs against
# AniDB IDs (and feeds Shokofin-style consumers later). Official image (not
# LSIO): config lives at /home/shoko/.shoko, so the config PVC mount path is
# overridden; PUID/PGID are honored. Mounts the shared media data PVC for
# import folders (configured in-app under /data).
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# AniDB talks over its own ports: UDP API on 9000, HTTP API on 9001 —
# world egress for those rides an extra CNP next to the standard 80/443
# (artwork CDN) policy.
#
# Version pinned to v5.3.3 — latest stable. Bump in a dedicated pass.
{
  den.aspects.kubernetes.services.media.shoko = {
    service-domains = [ "shoko" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.shoko-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/shoko-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "shoko";
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
        applications.shoko = {
          namespace = "media";

          helm.releases.shoko = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "shokoanime/server";
                    tag = "v5.3.3";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                  };
                  envFrom = [ ];
                  probes = {
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

              service.main = {
                controller = "main";
                ports.http.port = 8111;
              };

              persistence = {
                # Official image keeps its state in /home/shoko/.shoko (no /config).
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "10Gi";
                  storageClass = "longhorn";
                  globalMounts = [ { path = "/home/shoko/.shoko"; } ];
                };
                data = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [ { path = "/data"; } ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-shoko.spec = {
                description = "Allow Envoy Gateway proxies to reach shoko.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "shoko";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "8111";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-shoko.spec = {
                description = "Allow shoko to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "shoko";
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

              # Artwork/banner CDNs over HTTPS.
              allow-internet-egress-shoko.spec = {
                description = "Allow shoko to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "shoko";
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

            httpRoutes.shoko.spec = {
              hostnames = [ (cluster.domainFor "shoko") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "shoko"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "shoko";
                      port = 8111;
                    }
                  ];
                }
              ];
            };

            securityPolicies."shoko-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "shoko";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "shoko";
                clientID = "shoko";
                clientSecret.name = "shoko-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.shoko-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.shoko-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

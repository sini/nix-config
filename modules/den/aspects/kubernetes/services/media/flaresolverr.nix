# FlareSolverr — proxy that solves Cloudflare/JS challenges for the indexers.
#
# Stateless: no config PVC, no route, no OIDC. Reached in-cluster by Prowlarr
# (a FlareSolverr "indexer proxy") on its API port. It must reach the public
# internet (that is its entire job), so it gets a world-egress CNP on 80/443.
#
# The service is described inline (formerly built via the mkMediaApp helper):
# route-less and OIDC-less, so it declares an empty service-domains, no
# age-secrets, no HTTPRoute, and no SecurityPolicy. Only the DNS-egress and
# internet-egress baseline CiliumNetworkPolicies are emitted.
{
  den.aspects.kubernetes.services.media.flaresolverr = {
    service-domains = [ ];

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        ...
      }:
      {
        applications.flaresolverr = {
          namespace = "media";

          helm.releases.flaresolverr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "ghcr.io/flaresolverr/flaresolverr";
                    tag = "v3.5.0";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    LOG_LEVEL = "info";
                  };
                  envFrom = [ ];
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 8191;
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-dns-egress-flaresolverr.spec = {
                description = "Allow flaresolverr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "flaresolverr";
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

              allow-internet-egress-flaresolverr.spec = {
                description = "Allow flaresolverr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "flaresolverr";
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
            };
          };
        };
      };
  };
}

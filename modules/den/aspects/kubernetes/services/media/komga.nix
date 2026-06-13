# Komga — comics / manga / ebook server.
#
# Simple stateless-ish app: routed + OIDC-protected UI on komga.json64.dev (no
# prod.nix services.komga entry — getDomainFor falls back to <name>.<domain> =
# komga.json64.dev, which the Kanidm "komga" client already targets), clientID
# "komga".
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# == Storage ==
# Komga keeps its state (an embedded H2/SQLite database, thumbnails cache, search
# index) under /config. We give it a 2Gi longhorn config PVC. The library lives
# on the shared media NFS — comics at /data/media/comics — mounted via the shared
# media-data-nfs PVC at /data; the library root is configured in-app (Komga points
# at /data/media/comics). A plain /data mount is sufficient; no subPath gymnastics.
#
# == Auth ==
# Stack convention = Envoy Gateway OIDC only (SecurityPolicy on the HTTPRoute).
# Komga's own user store still exists (it creates an initial admin on first boot);
# we keep gateway OIDC in front and leave Komga's native auth at its default. Komga
# also supports OAuth2/OIDC natively, but we do not wire it (gateway handles it).
#
# == Networking ==
# Baseline only: DNS egress + gateway ingress. Base Komga makes minimal external
# calls (cover/metadata enrichment is the separate Komf companion, not deployed
# here), so there is no internet-egress policy. Add it later if metadata fetching
# is enabled in-app. No postgres (Komga uses its embedded DB under /config).
#
# Version: pinned to the latest stable Komga 1.x release. Bump at deploy time.
{
  den.aspects.kubernetes.services.media.komga = {
    service-domains = [ "komga" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.komga-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/komga-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "komga";
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
        applications.komga = {
          namespace = "media";

          helm.releases.komga = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "ghcr.io/gotson/komga";
                    tag = "1.24.4";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                  };
                  envFrom = [ ];
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 25600;
              };

              persistence = {
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "2Gi";
                  storageClass = "longhorn";
                  globalMounts = [ { path = "/config"; } ];
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
              allow-gateway-ingress-komga.spec = {
                description = "Allow Envoy Gateway proxies to reach komga.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "komga";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "25600";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-komga.spec = {
                description = "Allow komga to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "komga";
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
            };

            httpRoutes.komga.spec = {
              hostnames = [ (cluster.domainFor "komga") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "komga"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "komga";
                      port = 25600;
                    }
                  ];
                }
              ];
            };

            securityPolicies."komga-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "komga";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "komga";
                clientID = "komga";
                clientSecret.name = "komga-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.komga-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.komga-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

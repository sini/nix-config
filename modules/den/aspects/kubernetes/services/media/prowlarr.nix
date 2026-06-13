# Prowlarr — indexer manager / proxy for the *arr stack.
#
# Postgres-backed (media-pg, main+log dbs), OIDC-protected UI via the gateway
# (AUTH__METHOD=External so Prowlarr trusts the gateway-authenticated identity),
# and a fixed API key from the shared media-arr-api-keys secret so the *arrs can
# register against it deterministically.
#
# The service is described inline (formerly via the _media-app.nix mkMediaApp
# helper): a bjw-s app-template release with a longhorn config PVC, baseline
# CiliumNetworkPolicies (gateway ingress, DNS egress, media-pg egress, internet
# egress), an HTTPRoute on the default-gateway, and a Kanidm OIDC SecurityPolicy.
#
# Version pinned to 2.4.0 — latest stable LSIO release (the pre-migration
# deployment in the media-user backup logs ran 2.3.0). Bump tags in a dedicated
# pass at deploy time.
{
  den.aspects.kubernetes.services.media.prowlarr = {
    service-domains = [ "prowlarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.prowlarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/prowlarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "prowlarr";
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
        applications.prowlarr = {
          namespace = "media";

          helm.releases.prowlarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/prowlarr";
                    tag = "2.4.0";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    "PROWLARR__POSTGRES__HOST" = "media-pg-rw";
                    "PROWLARR__POSTGRES__PORT" = "5432";
                    "PROWLARR__POSTGRES__MAINDB" = "prowlarr-main";
                    "PROWLARR__POSTGRES__LOGDB" = "prowlarr-log";
                    "PROWLARR__POSTGRES__USER".valueFrom.secretKeyRef = {
                      name = "media-pg-prowlarr-password";
                      key = "username";
                    };
                    "PROWLARR__POSTGRES__PASSWORD".valueFrom.secretKeyRef = {
                      name = "media-pg-prowlarr-password";
                      key = "password";
                    };
                    # Gateway handles authn; Prowlarr trusts it. The API key is
                    # fixed (shared secret) so downstream *arrs can register
                    # against this Prowlarr.
                    PROWLARR__AUTH__METHOD = "External";
                    PROWLARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "prowlarr";
                    };
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 9696;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 9696;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 9696;
              };

              # Prowlarr stores nothing on shared media/scratch — config PVC only.
              persistence.config = {
                type = "persistentVolumeClaim";
                accessMode = "ReadWriteOnce";
                size = "2Gi";
                storageClass = "longhorn";
                globalMounts = [ { path = "/config"; } ];
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-prowlarr.spec = {
                description = "Allow Envoy Gateway proxies to reach prowlarr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prowlarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "9696";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-prowlarr.spec = {
                description = "Allow prowlarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prowlarr";
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

              allow-postgres-egress-prowlarr.spec = {
                description = "Allow prowlarr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prowlarr";
                egress = [
                  {
                    toEndpoints = [
                      { matchLabels."cnpg.io/cluster" = "media-pg"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "5432";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # World egress (80/443): indexer searches + the Cardigann
              # definitions fetch are world-facing (core function; without this
              # the indexer API hangs on the definitions download and every
              # search fails).
              allow-internet-egress-prowlarr.spec = {
                description = "Allow prowlarr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prowlarr";
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

            httpRoutes.prowlarr.spec = {
              hostnames = [ (cluster.domainFor "prowlarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "prowlarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "prowlarr";
                      port = 9696;
                    }
                  ];
                }
              ];
            };

            securityPolicies."prowlarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "prowlarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "prowlarr";
                clientID = "prowlarr";
                clientSecret.name = "prowlarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.prowlarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.prowlarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

# Whisparr — adult-content PVR (Radarr fork) for the *arr stack.
#
# Uses the hotio image rather than LSIO (hotio is the maintained source for
# Whisparr). The backup config.xml shows <Branch>v2</Branch> (Whisparr v2, the
# Radarr-derived line — NOT the v3/"eros" rewrite), so the Servarr env
# convention applies and the prefix is WHISPARR__ (verified against the v2
# branding). Postgres-backed (media-pg, whisparr-main + whisparr-log dbs),
# OIDC-protected UI via the gateway, fixed API key from media-arr-api-keys.
# hotio honours PUID/PGID like LSIO.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version: archive ran v2.0.0.1750, but hotio prunes old point releases; the
# closest pinned v2 tag still published is `v2-2.2.0-release.108`. Bump in the
# dedicated tag pass at deploy time.
{
  den.aspects.kubernetes.services.media.whisparr = {
    service-domains = [ "whisparr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.whisparr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/whisparr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "whisparr";
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
        applications.whisparr = {
          namespace = "media";

          helm.releases.whisparr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "ghcr.io/hotio/whisparr";
                    tag = "v2-2.2.0-release.108";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    WHISPARR__POSTGRES__HOST = "media-pg-rw";
                    WHISPARR__POSTGRES__PORT = "5432";
                    WHISPARR__POSTGRES__MAINDB = "whisparr-main";
                    WHISPARR__POSTGRES__LOGDB = "whisparr-log";
                    WHISPARR__POSTGRES__USER.valueFrom.secretKeyRef = {
                      name = "media-pg-whisparr-password";
                      key = "username";
                    };
                    WHISPARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-pg-whisparr-password";
                      key = "password";
                    };
                    WHISPARR__AUTH__METHOD = "External";
                    WHISPARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "whisparr";
                    };
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 6969;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 6969;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 6969;
              };

              persistence = {
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "2Gi";
                  storageClass = "longhorn";
                  labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                  globalMounts = [ { path = "/config"; } ];
                };
                data = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [ { path = "/data"; } ];
                };
                scratch = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-scratch-nfs";
                  globalMounts = [ { path = "/scratch"; } ];
                };
                # MediaCover on the NAS (pre-staged from the archive): bulk
                # re-fetchable artwork keyed by DB id, kept off the longhorn
                # config PVC.
                metadata = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-data-nfs";
                  globalMounts = [
                    {
                      path = "/config/MediaCover";
                      subPath = "media/metadata/whisparr/MediaCover";
                    }
                  ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-whisparr.spec = {
                description = "Allow Envoy Gateway proxies to reach whisparr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "whisparr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
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

              allow-dns-egress-whisparr.spec = {
                description = "Allow whisparr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "whisparr";
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

              allow-postgres-egress-whisparr.spec = {
                description = "Allow whisparr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "whisparr";
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

              # World egress (80/443): site/scene metadata + artwork come from
              # its metadata API, a direct world call.
              allow-internet-egress-whisparr.spec = {
                description = "Allow whisparr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "whisparr";
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

            httpRoutes.whisparr.spec = {
              hostnames = [ (cluster.domainFor "whisparr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "whisparr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "whisparr";
                      port = 6969;
                    }
                  ];
                }
              ];
            };

            securityPolicies."whisparr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "whisparr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "whisparr";
                clientID = "whisparr";
                clientSecret.name = "whisparr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.whisparr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.whisparr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

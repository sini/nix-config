# Lidarr — music PVR / library manager for the *arr stack.
#
# Postgres-backed (media-pg, lidarr-main + lidarr-log dbs), OIDC-protected UI via
# the gateway (AUTH__METHOD=External), fixed API key from the shared
# media-arr-api-keys secret. Mounts the shared media data PVC (/data) and the
# NFS scratch PVC (/scratch) for imports.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version pinned to 3.1.0 — latest stable LSIO release (the release in the
# media-user backup logs was 2.14.5.4836). Bump tags in a dedicated pass at
# deploy time.
{
  den.aspects.kubernetes.services.media.lidarr = {
    service-domains = [ "lidarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.lidarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/lidarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "lidarr";
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
        applications.lidarr = {
          namespace = "media";

          helm.releases.lidarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/lidarr";
                    tag = "3.1.0";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    LIDARR__POSTGRES__HOST = "media-pg-rw";
                    LIDARR__POSTGRES__PORT = "5432";
                    LIDARR__POSTGRES__MAINDB = "lidarr-main";
                    LIDARR__POSTGRES__LOGDB = "lidarr-log";
                    LIDARR__POSTGRES__USER.valueFrom.secretKeyRef = {
                      name = "media-pg-lidarr-password";
                      key = "username";
                    };
                    LIDARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-pg-lidarr-password";
                      key = "password";
                    };
                    LIDARR__AUTH__METHOD = "External";
                    LIDARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "lidarr";
                    };
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 8686;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 8686;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 8686;
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
                      subPath = "media/metadata/lidarr/MediaCover";
                    }
                  ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-lidarr.spec = {
                description = "Allow Envoy Gateway proxies to reach lidarr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "lidarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
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
                ];
              };

              allow-dns-egress-lidarr.spec = {
                description = "Allow lidarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "lidarr";
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

              allow-postgres-egress-lidarr.spec = {
                description = "Allow lidarr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "lidarr";
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

              # World egress (80/443): artist/album metadata + artwork come from
              # the Servarr metadata proxy (MusicBrainz front), a direct world
              # call.
              allow-internet-egress-lidarr.spec = {
                description = "Allow lidarr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "lidarr";
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

            httpRoutes.lidarr.spec = {
              hostnames = [ (cluster.domainFor "lidarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "lidarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "lidarr";
                      port = 8686;
                    }
                  ];
                }
              ];
            };

            securityPolicies."lidarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "lidarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "lidarr";
                clientID = "lidarr";
                clientSecret.name = "lidarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.lidarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.lidarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

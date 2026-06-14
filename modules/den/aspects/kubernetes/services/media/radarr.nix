# Radarr — movie PVR / library manager for the *arr stack.
#
# Postgres-backed (media-pg, radarr-main + radarr-log dbs), OIDC-protected UI via
# the gateway (AUTH__METHOD=External), fixed API key from the shared
# media-arr-api-keys secret. Mounts the shared media data PVC (/data) and the
# NFS scratch PVC (/scratch) for imports.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version pinned to 6.2.1 — latest stable LSIO release (the release in the
# media-user backup logs was 6.0.4.10291). Bump tags in a dedicated pass at
# deploy time.
{
  den.aspects.kubernetes.services.media.radarr = {
    service-domains = [ "radarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.radarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/radarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "radarr";
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
        applications.radarr = {
          namespace = "media";

          helm.releases.radarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/radarr";
                    tag = "6.2.1";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    RADARR__POSTGRES__HOST = "media-pg-rw";
                    RADARR__POSTGRES__PORT = "5432";
                    RADARR__POSTGRES__MAINDB = "radarr-main";
                    RADARR__POSTGRES__LOGDB = "radarr-log";
                    RADARR__POSTGRES__USER.valueFrom.secretKeyRef = {
                      name = "media-pg-radarr-password";
                      key = "username";
                    };
                    RADARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-pg-radarr-password";
                      key = "password";
                    };
                    RADARR__AUTH__METHOD = "External";
                    RADARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "radarr";
                    };
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 7878;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 7878;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 7878;
              };

              persistence = {
                # MediaCover thumbnails accumulate; give the config PVC headroom.
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "5Gi";
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
                      subPath = "media/metadata/radarr/MediaCover";
                    }
                  ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-radarr.spec = {
                description = "Allow Envoy Gateway proxies to reach radarr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "radarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
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
                ];
              };

              allow-dns-egress-radarr.spec = {
                description = "Allow radarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "radarr";
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

              allow-postgres-egress-radarr.spec = {
                description = "Allow radarr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "radarr";
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

              # World egress (80/443): movie metadata + artwork come from the
              # Servarr metadata API, a direct world call.
              allow-internet-egress-radarr.spec = {
                description = "Allow radarr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "radarr";
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

            httpRoutes.radarr.spec = {
              hostnames = [ (cluster.domainFor "radarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "radarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "radarr";
                      port = 7878;
                    }
                  ];
                }
              ];
            };

            securityPolicies."radarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "radarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "radarr";
                clientID = "radarr";
                clientSecret.name = "radarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.radarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.radarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

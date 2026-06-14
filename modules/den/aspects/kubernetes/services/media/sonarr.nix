# Sonarr — TV series PVR / library manager for the *arr stack.
#
# Postgres-backed (media-pg, sonarr-main + sonarr-log dbs), OIDC-protected UI via
# the gateway (AUTH__METHOD=External so Sonarr trusts the gateway-authenticated
# identity), fixed API key from the shared media-arr-api-keys secret. Mounts the
# shared media data PVC (/data) and the NFS scratch PVC (/scratch) for imports.
#
# The service is described inline (formerly built via the mkMediaApp helper).
#
# Version pinned to 4.0.17 — latest stable LSIO tag in the v4 line (the v4-era
# release in the media-user backup logs was 4.0.16.2944). Bump tags in a
# dedicated pass at deploy time.
{
  den.aspects.kubernetes.services.media.sonarr = {
    service-domains = [ "sonarr" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.sonarr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/sonarr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "sonarr";
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
        applications.sonarr = {
          namespace = "media";

          helm.releases.sonarr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/sonarr";
                    tag = "4.0.17";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    SONARR__POSTGRES__HOST = "media-pg-rw";
                    SONARR__POSTGRES__PORT = "5432";
                    SONARR__POSTGRES__MAINDB = "sonarr-main";
                    SONARR__POSTGRES__LOGDB = "sonarr-log";
                    SONARR__POSTGRES__USER.valueFrom.secretKeyRef = {
                      name = "media-pg-sonarr-password";
                      key = "username";
                    };
                    SONARR__POSTGRES__PASSWORD.valueFrom.secretKeyRef = {
                      name = "media-pg-sonarr-password";
                      key = "password";
                    };
                    SONARR__AUTH__METHOD = "External";
                    SONARR__AUTH__APIKEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "sonarr";
                    };
                  };
                  envFrom = [ ];
                  # Servarr HTTP health endpoint.
                  probes = {
                    liveness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 8989;
                    };
                    readiness = {
                      enabled = true;
                      type = "HTTP";
                      path = "/ping";
                      port = 8989;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = 8989;
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
                      subPath = "media/metadata/sonarr/MediaCover";
                    }
                  ];
                };
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-sonarr.spec = {
                description = "Allow Envoy Gateway proxies to reach sonarr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sonarr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
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
                ];
              };

              allow-dns-egress-sonarr.spec = {
                description = "Allow sonarr to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sonarr";
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

              allow-postgres-egress-sonarr.spec = {
                description = "Allow sonarr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sonarr";
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

              # World egress (80/443): series metadata + artwork come from the
              # Servarr metadata API (skyhook), a direct world call.
              allow-internet-egress-sonarr.spec = {
                description = "Allow sonarr to reach the public internet.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "sonarr";
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

            httpRoutes.sonarr.spec = {
              hostnames = [ (cluster.domainFor "sonarr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "sonarr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "sonarr";
                      port = 8989;
                    }
                  ];
                }
              ];
            };

            securityPolicies."sonarr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "sonarr";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "sonarr";
                clientID = "sonarr";
                clientSecret.name = "sonarr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.sonarr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.sonarr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

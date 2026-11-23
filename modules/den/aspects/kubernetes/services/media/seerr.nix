# Seerr — media request and discovery manager for Jellyfin (the merged
# Overseerr/Jellyseerr, ghcr.io/seerr-team/seerr).
#
# Laid out like the other media apps: a bjw-s app-template release, a longhorn
# config PVC, media-pg for its database, baseline CiliumNetworkPolicies, an
# HTTPRoute on the default-gateway and a Kanidm OIDC SecurityPolicy (media.access).
# Seerr's own sign-in is with Jellyfin accounts, behind the gateway's OIDC.
#
# Postgres via Seerr's DB_* variables, against the single `seerr` database with
# media-pg-seerr-password's credentials. The image runs as `node` (1000:1000), so
# the pod runs as that user with fsGroup 1000 to own the config PVC.
#
# Seerr's settings (Jellyfin at http://jellyfin.media.svc:8096, Sonarr and Radarr
# at http://{sonarr,radarr}.media.svc:{8989,7878}) live in its settings.json and
# are entered in its setup wizard; they are not rendered here.
#
# Its callers and callees: the gateway (ingress, here), media-pg and TMDB (egress,
# here), Jellyfin (egress here; Jellyfin's ingress in jellyfin.nix) and
# Sonarr/Radarr (network-policy.nix edges).
#
# Image tracked via the oci-image-updater at the rolling `latest` tag,
# digest-pinned in images/seerr-team/seerr.
let
  serviceDomains = [ "seerr" ];
  port = 5055;
  uid = 1000;
  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
in
{
  den.aspects.kubernetes.services.media.seerr = {
    served-domains = { cluster, ... }: cluster.servedDomains serviceDomains;

    age-secrets =
      { environment, ... }:
      {
        age.secrets.seerr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/seerr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "seerr";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        images,
        ...
      }:
      {
        applications.seerr = {
          namespace = "media";

          helm.releases.seerr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              defaultPodOptions.securityContext = {
                runAsUser = uid;
                runAsGroup = uid;
                runAsNonRoot = true;
                fsGroup = uid;
                fsGroupChangePolicy = "OnRootMismatch";
              };

              controllers.main = {
                type = "deployment";

                containers.main = {
                  image = {
                    inherit (images."seerr-team/seerr") repository digest;
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PORT = toString port;
                    DB_TYPE = "postgres";
                    DB_HOST = "media-pg-rw";
                    DB_PORT = "5432";
                    DB_NAME = "seerr";
                    DB_USER.valueFrom.secretKeyRef = {
                      name = "media-pg-seerr-password";
                      key = "username";
                    };
                    DB_PASS.valueFrom.secretKeyRef = {
                      name = "media-pg-seerr-password";
                      key = "password";
                    };
                  };
                  securityContext = {
                    allowPrivilegeEscalation = false;
                    capabilities.drop = [ "ALL" ];
                  };
                  probes = {
                    liveness.enabled = true;
                    readiness.enabled = true;
                    startup = {
                      enabled = true;
                      # The first start runs the schema migrations.
                      spec.failureThreshold = 60;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = port;
              };

              persistence.config = {
                type = "persistentVolumeClaim";
                accessMode = "ReadWriteOnce";
                # settings.json, logs and the image cache.
                size = "5Gi";
                storageClass = "longhorn";
                labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                globalMounts = [ { path = "/app/config"; } ];
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-seerr.spec = {
                description = "Allow Envoy Gateway proxies to reach seerr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "seerr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };

              allow-postgres-egress-seerr.spec = {
                description = "Allow seerr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "seerr";
                egress = [
                  {
                    toEndpoints = [
                      { matchLabels."cnpg.io/cluster" = "media-pg"; }
                    ];
                    toPorts = [ { ports = [ (tcp 5432) ]; } ];
                  }
                ];
              };

              # Jellyfin's ingress side admits seerr in jellyfin.nix.
              allow-jellyfin-egress-seerr.spec = {
                description = "Allow seerr to reach jellyfin's API.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "seerr";
                egress = [
                  {
                    toEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "jellyfin"; }
                    ];
                    toPorts = [ { ports = [ (tcp 8096) ]; } ];
                  }
                ];
              };

              # TMDB (metadata and artwork) and the notification agents, all HTTPS.
              allow-internet-egress-seerr.spec = {
                description = "Allow seerr to reach the public internet over HTTPS.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "seerr";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [ { ports = [ (tcp 443) ]; } ];
                  }
                ];
              };
            };

            httpRoutes.seerr.spec = {
              hostnames = [ (cluster.domainFor "seerr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "seerr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "seerr";
                      inherit port;
                    }
                  ];
                }
              ];
            };

            securityPolicies."seerr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "seerr";
                }
              ];
              oidc = {
                provider = cluster.secrets.oidcProviderFor "seerr";
                clientID = "seerr";
                clientSecret.name = "seerr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.seerr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.seerr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}

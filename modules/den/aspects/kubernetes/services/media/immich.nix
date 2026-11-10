# immich — photo and video library, on immich.json64.dev.
#
# Two controllers of one app-template release: `main` (immich-server, web + API
# + job workers) and `ml` (immich-machine-learning: CLIP smart search, faces).
# Both pods carry app.kubernetes.io/name=immich, so every network policy below
# also selects on app.kubernetes.io/controller. ML runs on CPU.
#
# == Config ==
# immich-server reads IMMICH_CONFIG_FILE, which makes the covered settings
# read-only in the admin UI. The file embeds the OIDC client secret, so it is a
# template-file secret mounted from the `immich` Secret.
#
# == Auth ==
# Native OIDC against kanidm (client `immich`), login gated by the immich.access
# scope map, password login off. kanidm signs ES256 (immich defaults to RS256).
# The mobile app's app.immich:/// callback goes through immich's own
# /api/oauth/mobile-redirect, so kanidm only sees https redirect URIs. Role:
# kanidm emits immich_role = "admin" for immich.admins; immich syncs a claim on
# each login but leaves an absent one unchanged, so removing someone from
# immich.admins does not demote them by itself.
#
# == Storage ==
#   library  the NAS (immich-nfs, vault:/volume2/data, subPath immich): uploads,
#            thumbnails, encoded video. The irreplaceable part, on the durable
#            bulk tier.
#   cache    immich-ml-cache, longhorn-single: downloaded models, regenerable,
#            not backed up.
# immich's own nightly pg_dumpall backup needs superuser, so it is off; the
# database is backed up by immich-pg's CNPG volumeSnapshots.
#
# == Networking ==
# Gateway → server 2283; server → ml 3003; server → immich-redis 6379; both pods
# → world 443 (server: kanidm token/userinfo; ml: model downloads).
let
  serviceDomains = [ "immich" ];
  namespace = "immich";
  protect."argocd.argoproj.io/sync-options" = "Prune=false,Delete=false";
  port = 2283;
  mlPort = 3003;
  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
  pod = controller: {
    "app.kubernetes.io/name" = "immich";
    "app.kubernetes.io/controller" = controller;
  };
in
{
  den.aspects.kubernetes.services.media.immich = {
    served-domains = { cluster, ... }: cluster.servedDomains serviceDomains;

    age-secrets =
      { environment, config, ... }:
      let
        domain = environment.getDomainFor "immich";
      in
      {
        age.secrets = {
          # The SAME .age file the kanidm host consumes for the immich OIDC
          # client (basicSecretFile in kanidm.nix) — both sides read one secret.
          immich-oidc-client-secret = {
            rekeyFile = environment.secretPath + "/oidc/immich-oidc-client-secret.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            sopsOutput = {
              file = "oidc";
              key = "immich";
            };
          };

          immich-redis-password = {
            rekeyFile = environment.secretPath + "/immich/redis-password.age";
            generator.script = "alnum";
            sopsOutput = {
              file = "immich";
              key = "redis-password";
            };
          };

          # rfc3986-secret draws only unreserved characters, so the secret needs
          # no JSON escaping.
          immich-config = {
            rekeyFile = environment.secretPath + "/immich/config.age";
            generator.script = "template-file";
            generator.dependencies = [ config.age.secrets.immich-oidc-client-secret ];
            settings.template = builtins.toJSON {
              backup.database.enabled = false;
              machineLearning = {
                enabled = true;
                urls = [ "http://immich-ml:${toString mlPort}" ];
              };
              # Upgrades go through the image pin.
              newVersionCheck.enabled = false;
              oauth = {
                enabled = true;
                autoLaunch = true;
                autoRegister = true;
                buttonText = "Login with Kanidm";
                clientId = "immich";
                clientSecret = "%immich-oidc-client-secret%";
                issuerUrl = "https://${environment.getDomainFor "kanidm"}/oauth2/openid/immich";
                scope = "openid email profile";
                signingAlgorithm = "ES256";
                roleClaim = "immich_role";
                mobileOverrideEnabled = true;
                mobileRedirectUri = "https://${domain}/api/oauth/mobile-redirect";
              };
              passwordLogin.enabled = false;
              server.externalDomain = "https://${domain}";
            };
            sopsOutput = {
              file = "immich";
              key = "config";
            };
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
      let
        nas = cluster.nfsVolumes.vault-nfs;
        image = name: { inherit (images."immich-app/${name}") repository digest; };
      in
      {
        applications.immich = {
          inherit namespace;

          helm.releases.immich = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers = {
                main = {
                  type = "deployment";
                  strategy = "Recreate";
                  containers.main = {
                    image = image "immich-server";
                    env = {
                      TZ = "America/Los_Angeles";
                      IMMICH_CONFIG_FILE = "/config/immich.json";
                      DB_HOSTNAME = "immich-pg-rw";
                      DB_DATABASE_NAME = "immich";
                      DB_USERNAME.valueFrom.secretKeyRef = {
                        name = "immich-pg-immich-password";
                        key = "username";
                      };
                      DB_PASSWORD.valueFrom.secretKeyRef = {
                        name = "immich-pg-immich-password";
                        key = "password";
                      };
                      # postgres.js `require`: TLS without verifying CNPG's self-signed CA.
                      DB_SSL_MODE = "require";
                      DB_VECTOR_EXTENSION = "vectorchord";
                      REDIS_HOSTNAME = "immich-redis";
                      REDIS_PASSWORD.valueFrom.secretKeyRef = {
                        name = "immich";
                        key = "redis-password";
                      };
                    };
                  };
                };

                ml = {
                  type = "deployment";
                  containers.main = {
                    image = image "immich-machine-learning";
                    env = {
                      TZ = "America/Los_Angeles";
                      MACHINE_LEARNING_CACHE_FOLDER = "/cache";
                    };
                  };
                };
              };

              service = {
                main = {
                  controller = "main";
                  ports.http.port = port;
                };
                ml = {
                  controller = "ml";
                  ports.http.port = mlPort;
                };
              };

              persistence = {
                config = {
                  type = "secret";
                  name = "immich";
                  advancedMounts.main.main = [
                    {
                      path = "/config/immich.json";
                      subPath = "config";
                      readOnly = true;
                    }
                  ];
                };
                library = {
                  type = "persistentVolumeClaim";
                  existingClaim = "immich-nfs";
                  advancedMounts.main.main = [
                    {
                      path = "/data";
                      subPath = "immich";
                    }
                  ];
                };
                cache = {
                  type = "persistentVolumeClaim";
                  existingClaim = "immich-ml-cache";
                  advancedMounts.ml.main = [ { path = "/cache"; } ];
                };
              };
            };
          };

          # Job queue (BullMQ). Ephemeral: immich re-queues missing work from
          # the database on its own scheduled jobs.
          helm.releases.immich-redis = {
            chart = charts.valkey.valkey;
            values = {
              fullnameOverride = "immich-redis";
              auth = {
                enabled = true;
                usersExistingSecret = "immich";
                aclUsers.default = {
                  permissions = "~* &* +@all";
                  passwordKey = "redis-password";
                };
              };
              persistence.enabled = false;
              service.port = 6379;
            };
          };

          resources = {
            # The NAS share, statically bound like media-data-nfs (media/base.nix),
            # so the library sits at a fixed, browsable path on the NAS.
            persistentVolumes.immich-nfs = {
              metadata.annotations = protect;
              spec = {
                capacity.storage = "1Ti";
                accessModes = [ "ReadWriteMany" ];
                persistentVolumeReclaimPolicy = "Retain";
                storageClassName = "";
                nfs = {
                  inherit (nas) server;
                  path = nas.share;
                };
                mountOptions = [
                  "nfsvers=4.1"
                  "noatime"
                ];
                claimRef = {
                  inherit namespace;
                  name = "immich-nfs";
                };
              };
            };

            persistentVolumeClaims = {
              immich-nfs = {
                metadata.annotations = protect;
                spec = {
                  accessModes = [ "ReadWriteMany" ];
                  storageClassName = "";
                  volumeName = "immich-nfs";
                  resources.requests.storage = "1Ti";
                };
              };

              immich-ml-cache.spec = {
                accessModes = [ "ReadWriteOnce" ];
                storageClassName = "longhorn-single";
                resources.requests.storage = "10Gi";
              };
            };

            httpRoutes.immich.spec = {
              hostnames = [ (cluster.domainFor "immich") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "immich"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      # Two controllers: app-template suffixes each Service with its id.
                      name = "immich-main";
                      inherit port;
                    }
                  ];
                }
              ];
            };

            secrets.immich = {
              type = "Opaque";
              stringData = {
                config = config.age.secrets.immich-config.sopsRef;
                redis-password = config.age.secrets.immich-redis-password.sopsRef;
              };
            };

            ciliumNetworkPolicies = {
              allow-gateway-ingress-immich.spec = {
                description = "Allow Envoy Gateway proxies to reach immich-server.";
                endpointSelector.matchLabels = pod "main";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };

              allow-immich-ingress-ml.spec = {
                description = "Allow immich-server to reach immich-machine-learning.";
                endpointSelector.matchLabels = pod "ml";
                ingress = [
                  {
                    fromEndpoints = [ { matchLabels = pod "main"; } ];
                    toPorts = [ { ports = [ (tcp mlPort) ]; } ];
                  }
                ];
              };

              # The valkey chart labels its pods app.kubernetes.io/instance=immich-redis.
              allow-immich-ingress-redis.spec = {
                description = "Allow immich-server to reach the immich-redis valkey.";
                endpointSelector.matchLabels."app.kubernetes.io/instance" = "immich-redis";
                ingress = [
                  {
                    fromEndpoints = [ { matchLabels = pod "main"; } ];
                    toPorts = [ { ports = [ (tcp 6379) ]; } ];
                  }
                ];
              };

              allow-immich-world-egress.spec = {
                description = "Allow immich to reach kanidm (server) and model downloads (ml).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "immich";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [ { ports = [ (tcp 443) ]; } ];
                  }
                ];
              };
            };
          };
        };
      };
  };
}

# paperless-ngx — document archive with OCR, on paperless.json64.dev.
#
# == Auth ==
# Native OIDC (django-allauth openid_connect provider `kanidm`), not the gateway
# SecurityPolicy: paperless owns the flow (/accounts/oidc/kanidm/login/ ->
# kanidm -> /accounts/oidc/kanidm/login/callback/) and keeps its own token auth
# for API clients (mobile apps, scripts), which can't follow a gateway redirect.
# Login is gated kanidm-side by the paperless.access scope map; the kanidm
# client emits a `groups` claim of ["admins"] for paperless.admins, and
# SOCIAL_ACCOUNT_SYNC_SUPERUSER_GROUP turns that into superuser on every login,
# so no local bootstrap account exists. Lockout recovery is
# `manage.py createsuperuser` in the pod. The regular login form is disabled.
#
# == Storage ==
#   data     paperless-data, replicated longhorn RWO: the search index, the
#            classifier model and thumbnails. Not on NFS (upstream: the index
#            needs working file locks). Enrolled in the nightly media-config
#            off-cluster backup.
#   media    the NAS (paperless-nfs, vault:/volume2/data, subPath
#            paperless/media): the originals and their OCR'd archive versions,
#            the irreplaceable part. The NAS is the durable bulk tier.
#   consume  the NAS, subPath paperless/consume: the inbox a scanner or the NAS's
#            own SMB share drops files into. NFS gives no inotify, so the
#            consumer polls.
#   export   the NAS, subPath paperless/export: `document_exporter` target.
# Files are written as the NAS media identity (USERMAP 1027:65536, the PUID/PGID
# the media apps use), so the share stays writable from the NAS side too.
#
# == Secrets ==
# Generated: the Django secret key, the valkey password and the OIDC client
# secret (shared with kanidm's client entry via one .age file). The broker URL
# and the allauth provider JSON each embed a secret mid-string, so they are
# template-file secrets whose sops value is a single ref.
#
# == Networking ==
# The gateway reaches paperless on 8000; paperless reaches paperless-pg and
# paperless-redis in-cluster (the clusterwide allow-internal-egress policy), and
# kanidm over world:443 for the server-side OIDC token/userinfo calls. No other
# internet egress: OCR is local.
let
  serviceDomains = [ "paperless" ];
  namespace = "paperless";
  protect."argocd.argoproj.io/sync-options" = "Prune=false,Delete=false";
  port = 8000;
  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
in
{
  den.aspects.kubernetes.services.documents.paperless = {
    service-domains = serviceDomains;
    served-domains = { cluster, ... }: cluster.servedDomains serviceDomains;

    age-secrets =
      { environment, config, ... }:
      {
        age.secrets = {
          # The SAME .age file the kanidm host consumes for the paperless OIDC
          # client (basicSecretFile in kanidm.nix) — both sides read one secret.
          paperless-oidc-client-secret = {
            rekeyFile = environment.secretPath + "/oidc/paperless-oidc-client-secret.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            sopsOutput = {
              file = "oidc";
              key = "paperless";
            };
          };

          paperless-secret-key = {
            rekeyFile = environment.secretPath + "/paperless/secret-key.age";
            generator.script = "hex";
            settings.length = 32;
            sopsOutput = {
              file = "paperless";
              key = "secret-key";
            };
          };

          paperless-redis-password = {
            rekeyFile = environment.secretPath + "/paperless/redis-password.age";
            generator.script = "alnum";
            sopsOutput = {
              file = "paperless";
              key = "redis-password";
            };
          };

          paperless-redis-url = {
            rekeyFile = environment.secretPath + "/paperless/redis-url.age";
            generator.script = "template-file";
            generator.dependencies = [ config.age.secrets.paperless-redis-password ];
            settings.template = "redis://:%paperless-redis-password%@paperless-redis:6379";
            sopsOutput = {
              file = "paperless";
              key = "redis-url";
            };
          };

          # rfc3986-secret draws only unreserved characters, so the secret needs
          # no JSON escaping.
          paperless-socialaccount-providers = {
            rekeyFile = environment.secretPath + "/paperless/socialaccount-providers.age";
            generator.script = "template-file";
            generator.dependencies = [ config.age.secrets.paperless-oidc-client-secret ];
            settings.template = builtins.toJSON {
              openid_connect = {
                SCOPE = [
                  "openid"
                  "profile"
                  "email"
                  "groups"
                ];
                APPS = [
                  {
                    provider_id = "kanidm";
                    name = "Kanidm";
                    client_id = "paperless";
                    secret = "%paperless-oidc-client-secret%";
                    settings = {
                      server_url = "https://${environment.getDomainFor "kanidm"}/oauth2/openid/paperless";
                      oauth_pkce_enabled = true;
                    };
                  }
                ];
              };
            };
            sopsOutput = {
              file = "paperless";
              key = "socialaccount-providers";
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
        domain = cluster.domainFor "paperless";
        nas = cluster.nfsVolumes.vault-nfs;
        secretEnv = name: key: { valueFrom.secretKeyRef = { inherit name key; }; };
      in
      {
        applications.paperless = {
          inherit namespace;

          helm.releases.paperless = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                # RWO data volume: one pod, replaced rather than overlapped.
                strategy = "Recreate";
                containers.main = {
                  image = {
                    inherit (images."paperless-ngx/paperless-ngx") repository digest;
                  };
                  env = {
                    PAPERLESS_URL = "https://${domain}";
                    PAPERLESS_TIME_ZONE = "America/Los_Angeles";
                    PAPERLESS_OCR_LANGUAGE = "eng";
                    USERMAP_UID = "1027";
                    USERMAP_GID = "65536";

                    PAPERLESS_DATA_DIR = "/data";
                    PAPERLESS_MEDIA_ROOT = "/media";
                    PAPERLESS_CONSUMPTION_DIR = "/consume";
                    PAPERLESS_CONSUMER_POLLING_INTERVAL = "30";
                    PAPERLESS_CONSUMER_RECURSIVE = "true";

                    PAPERLESS_DBENGINE = "postgresql";
                    PAPERLESS_DBHOST = "paperless-pg-rw";
                    PAPERLESS_DBNAME = "paperless";
                    PAPERLESS_DB_OPTIONS = "sslmode=require";
                    PAPERLESS_DBUSER = secretEnv "paperless-pg-paperless-password" "username";
                    PAPERLESS_DBPASS = secretEnv "paperless-pg-paperless-password" "password";

                    PAPERLESS_REDIS = secretEnv "paperless" "redis-url";
                    PAPERLESS_SECRET_KEY = secretEnv "paperless" "secret-key";

                    PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
                    PAPERLESS_SOCIALACCOUNT_PROVIDERS = secretEnv "paperless" "socialaccount-providers";
                    PAPERLESS_SOCIAL_AUTO_SIGNUP = "true";
                    PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS = "true";
                    PAPERLESS_SOCIAL_ACCOUNT_SYNC_SUPERUSER_GROUP = "admins";
                    PAPERLESS_DISABLE_REGULAR_LOGIN = "true";
                    PAPERLESS_REDIRECT_LOGIN_TO_SSO = "true";
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = port;
              };

              persistence = {
                data = {
                  type = "persistentVolumeClaim";
                  existingClaim = "paperless-data";
                  globalMounts = [ { path = "/data"; } ];
                };
                nas = {
                  type = "persistentVolumeClaim";
                  existingClaim = "paperless-nfs";
                  globalMounts =
                    map
                      (dir: {
                        path = "/${dir}";
                        subPath = "paperless/${dir}";
                      })
                      [
                        "media"
                        "consume"
                        "export"
                      ];
                };
              };
            };
          };

          # Celery broker and cache. Ephemeral: queued tasks are re-derivable
          # (the consumer re-finds files still in /consume).
          helm.releases.paperless-redis = {
            chart = charts.valkey.valkey;
            values = {
              fullnameOverride = "paperless-redis";
              auth = {
                enabled = true;
                usersExistingSecret = "paperless";
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
            # The NAS share, statically bound like media-data-nfs (media/base.nix):
            # the subPaths are fixed paths a scanner can be pointed at, which a
            # dynamically provisioned per-PV subDir would not be.
            persistentVolumes.paperless-nfs = {
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
                  name = "paperless-nfs";
                };
              };
            };

            persistentVolumeClaims = {
              paperless-nfs = {
                metadata.annotations = protect;
                spec = {
                  accessModes = [ "ReadWriteMany" ];
                  storageClassName = "";
                  volumeName = "paperless-nfs";
                  resources.requests.storage = "1Ti";
                };
              };

              paperless-data = {
                metadata.labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                spec = {
                  accessModes = [ "ReadWriteOnce" ];
                  storageClassName = "longhorn";
                  resources.requests.storage = "10Gi";
                };
              };
            };

            httpRoutes.paperless.spec = {
              hostnames = [ domain ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "paperless"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "paperless";
                      inherit port;
                    }
                  ];
                }
              ];
            };

            secrets = {
              paperless = {
                type = "Opaque";
                stringData = {
                  secret-key = config.age.secrets.paperless-secret-key.sopsRef;
                  redis-password = config.age.secrets.paperless-redis-password.sopsRef;
                  redis-url = config.age.secrets.paperless-redis-url.sopsRef;
                  socialaccount-providers = config.age.secrets.paperless-socialaccount-providers.sopsRef;
                };
              };
            };

            ciliumNetworkPolicies = {
              allow-gateway-ingress-paperless.spec = {
                description = "Allow Envoy Gateway proxies to reach paperless.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "paperless";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };

              # OIDC token/userinfo calls go server-side to kanidm, outside the
              # cluster (world entity).
              allow-paperless-kanidm-egress.spec = {
                description = "Allow paperless to reach kanidm for OIDC token/userinfo calls.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "paperless";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [ { ports = [ (tcp 443) ]; } ];
                  }
                ];
              };

              # The valkey chart labels its pods app.kubernetes.io/instance=paperless-redis.
              allow-paperless-ingress-redis.spec = {
                description = "Allow paperless to reach the paperless-redis valkey.";
                endpointSelector.matchLabels."app.kubernetes.io/instance" = "paperless-redis";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "paperless"; }
                    ];
                    toPorts = [ { ports = [ (tcp 6379) ]; } ];
                  }
                ];
              };
            };
          };
        };
      };
  };
}

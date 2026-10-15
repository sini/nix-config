# mas — the Matrix Authentication Service for json64.dev, served at
# matrix-auth.json64.dev. Synapse delegates all authentication to it, which is
# what lets OAuth 2.0 clients (Element X) log in; legacy clients use its
# compatibility layer for /login, /logout and /refresh.
#
# Login is kanidm, as MAS's only upstream provider. It reuses kanidm's `synapse`
# client: the same issuer keeps every user's subject, so the links syn2mas
# imports from Synapse stay valid. Passwords are off; the bcrypt scheme exists
# only because syn2mas requires one to import into.
#
# Config is split like Synapse's: the non-secret config.yaml (ConfigMap, built
# here) and secrets.yaml (a template-file age secret holding the database URI,
# which has no *_file option). The other secrets are mounted as files.
#
# Server admins are kanidm's `admins` group, routed here as `idm-users`
# (kanidm.nix → cluster-collect-idm-users): MAS lets them request Synapse's admin
# scope, which Ketesa (matrix-admin.nix) asks for.
#
# The import from Synapse's own login (docs/runbooks/matrix-mas-migration.md) is
# done; its Job stays declared, disabled, and is the only consumer of Synapse's
# config mounted here.
{ lib, ... }:
let
  serviceDomains = [ "matrix-auth" ];
  namespace = "matrix";
  name = "matrix-authentication-service";
  port = 8080;
  adminGroup = "admins";
  # The one-time import from Synapse. Done; true renders its Job again.
  syn2mas = false;
  uid = 65532; # the image's distroless nonroot user
  # Upstream provider id, also in kanidm's redirect URL (kanidm.nix). Permanent.
  kanidmProviderId = "01M4YHS31NGAA65EM4FZ07BJZ4";

  secretsTemplate = ''
    database:
      uri: "postgresql://mas:%matrix-pg-mas-password%@matrix-pg-rw.${namespace}.svc.cluster.local:5432/mas?sslmode=require"
  '';

  mkNetworkPolicy = description: rule: {
    spec = {
      inherit description;
      endpointSelector.matchLabels."app.kubernetes.io/name" = name;
    }
    // rule;
  };

  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
in
{
  den.aspects.kubernetes.services.communication.matrix.mas = {
    service-domains = serviceDomains;
    served-domains = { cluster, ... }: cluster.servedDomains serviceDomains;

    age-secrets =
      { environment, config, ... }:
      {
        age.secrets = {
          # Encrypts cookies and database fields. Never change it once MAS has run.
          matrix-mas-encryption-key = {
            rekeyFile = environment.secretPath + "/matrix-mas/encryption-key.age";
            generator.script = "hex";
            settings.length = 32;
            sopsOutput = {
              file = "matrix-mas";
              key = "encryption-key";
            };
          };
          matrix-mas-signing-key = {
            rekeyFile = environment.secretPath + "/matrix-mas/signing-key.age";
            generator.script = "rsa-private-key";
            sopsOutput = {
              file = "matrix-mas";
              key = "signing-key";
            };
          };
          # Authenticates MAS and Synapse to each other. Admin-equivalent.
          matrix-mas-shared-secret = {
            rekeyFile = environment.secretPath + "/matrix-mas/shared-secret.age";
            generator.script = "rfc3986-secret";
            sopsOutput = {
              file = "matrix-mas";
              key = "shared-secret";
            };
          };
          matrix-mas-secrets-yaml = {
            rekeyFile = environment.secretPath + "/matrix-mas/secrets-yaml.age";
            generator.script = "template-file";
            generator.dependencies = [ config.age.secrets.matrix-pg-mas-password ];
            settings.template = secretsTemplate;
            sopsOutput = {
              file = "matrix-mas";
              key = "secrets-yaml";
            };
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        idm-users,
        images,
        ...
      }:
      let
        admins = lib.sort lib.lessThan (
          map (u: u.name) (
            lib.filter (u: u.environment == cluster.environment && lib.elem adminGroup u.groups) idm-users
          )
        );
        masConfig = {
          http = {
            public_base = "https://${cluster.domainFor "matrix-auth"}/";
            listeners = [
              {
                name = "web";
                resources = map (n: { name = n; }) [
                  "discovery"
                  "human"
                  "oauth"
                  "compat"
                  "graphql"
                  "assets"
                  "health"
                ];
                binds = [ { address = "[::]:${toString port}"; } ];
              }
            ];
          };
          matrix = {
            kind = "synapse";
            homeserver = "json64.dev";
            endpoint = "http://synapse.${namespace}.svc.cluster.local:8008";
            secret_file = "/secrets/shared-secret";
          };
          secrets = {
            encryption_file = "/secrets/encryption-key";
            keys = [ { key_file = "/secrets/signing.key"; } ];
          };
          passwords = {
            enabled = false;
            schemes = [
              {
                version = 1;
                algorithm = "bcrypt";
                unicode_normalization = true;
              }
              {
                version = 2;
                algorithm = "argon2id";
              }
            ];
          };
          policy.data.admin_users = admins;
          upstream_oauth2.providers = [
            {
              id = kanidmProviderId;
              # Synapse's idp_id `kanidm`, prefixed as Synapse stores it.
              synapse_idp_id = "oidc-kanidm";
              human_name = "json64 (kanidm)";
              issuer = cluster.secrets.oidcIssuerFor "synapse";
              client_id = "synapse";
              client_secret_file = "/secrets/oidc-client-secret";
              token_endpoint_auth_method = "client_secret_basic";
              # kanidm signs id tokens with ES256, not the RS256 default.
              id_token_signed_response_alg = "ES256";
              pkce_method = "always";
              scope = "openid profile email";
              claims_imports = {
                skip_confirmation = true;
                localpart = {
                  action = "require";
                  template = "{{ user.preferred_username }}";
                };
                displayname = {
                  action = "force";
                  template = "{{ user.name }}";
                };
                email = {
                  action = "force";
                  template = "{{ user.email }}";
                };
              };
            }
          ];
        };

        configArgs = [
          "--config"
          "/config/config.yaml"
          "--config"
          "/secrets/secrets.yaml"
        ];
        synapseConfigArgs = [
          "--synapse-config"
          "/synapse/homeserver.yaml"
          "--synapse-config"
          "/synapse/secrets.yaml"
        ];
        container = args: {
          image = {
            inherit (images."element-hq/matrix-authentication-service") repository digest;
          };
          inherit args;
        };

        secretFile = path: key: {
          inherit path;
          subPath = key;
          readOnly = true;
        };
      in
      {
        applications.${name} = {
          inherit namespace;

          helm.releases.${name} = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              defaultPodOptions.securityContext = {
                runAsNonRoot = true;
                runAsUser = uid;
                runAsGroup = uid;
              };
              controllers.main = {
                type = "deployment";
                replicas = 1;
                containers.main = container ([ "server" ] ++ configArgs) // {
                  probes = lib.genAttrs [ "liveness" "readiness" ] (_: {
                    enabled = true;
                    custom = true;
                    spec.httpGet = {
                      path = "/health";
                      inherit port;
                    };
                  });
                };
              };
              # The import, run with Synapse stopped and MAS not serving. No
              # `syn2mas check` step: it exits non-zero on warnings, and migrate runs
              # the same checks and stops only on errors.
              controllers.syn2mas-migrate = {
                enabled = syn2mas;
                type = "job";
                # Jobs are immutable: each migration step is its own Job.
                forceRename = "mas-syn2mas-migrate";
                job.backoffLimit = 0;
                pod.restartPolicy = "Never";
                containers.main = container (
                  [
                    "syn2mas"
                    "migrate"
                  ]
                  ++ configArgs
                  ++ synapseConfigArgs
                );
              };
              service.main = {
                controller = "main";
                ports.http.port = port;
              };
              persistence = {
                config = {
                  type = "configMap";
                  name = "${name}-config";
                  globalMounts = [ { path = "/config"; } ];
                };
                secrets = {
                  type = "secret";
                  name = "matrix-mas";
                  globalMounts = [
                    (secretFile "/secrets/secrets.yaml" "secrets.yaml")
                    (secretFile "/secrets/encryption-key" "encryption-key")
                    (secretFile "/secrets/signing.key" "signing.key")
                    (secretFile "/secrets/shared-secret" "shared-secret")
                  ];
                };
                oidc = {
                  type = "secret";
                  name = "synapse-oidc-client-secret";
                  globalMounts = [ (secretFile "/secrets/oidc-client-secret" "client-secret") ];
                };
                # Synapse's config, for the import only.
                synapse-config = {
                  enabled = syn2mas;
                  type = "configMap";
                  name = "synapse-config";
                  advancedMounts.syn2mas-migrate.main = [
                    (secretFile "/synapse/homeserver.yaml" "homeserver.yaml")
                  ];
                };
                synapse-secrets = {
                  enabled = syn2mas;
                  type = "secret";
                  name = "matrix-synapse";
                  advancedMounts.syn2mas-migrate.main = [ (secretFile "/synapse/secrets.yaml" "secrets.yaml") ];
                };
              };
            };
          };

          resources = {
            configMaps."${name}-config".data."config.yaml" = builtins.toJSON masConfig;

            httpRoutes.${name}.spec = {
              hostnames = [ (cluster.domainFor "matrix-auth") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "matrix-auth"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      inherit name port;
                    }
                  ];
                }
              ];
            };

            # MAS's compatibility layer for legacy clients, on the homeserver's own
            # host. The longer prefixes win over synapse.nix's /_matrix route.
            httpRoutes."${name}-compat".spec = {
              hostnames = [ (cluster.domainFor "matrix") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "matrix"}-https";
                }
              ];
              rules = [
                {
                  matches =
                    lib.concatMap
                      (version: [
                        {
                          path = {
                            type = "PathPrefix";
                            value = "/_matrix/client/${version}/login";
                          };
                        }
                        {
                          path = {
                            type = "PathPrefix";
                            value = "/_matrix/client/${version}/logout";
                          };
                        }
                        {
                          path = {
                            type = "PathPrefix";
                            value = "/_matrix/client/${version}/refresh";
                          };
                        }
                      ])
                      [
                        "v3"
                        "r0"
                      ];
                  backendRefs = [
                    {
                      inherit name port;
                    }
                  ];
                }
              ];
            };

            secrets.matrix-mas = {
              type = "Opaque";
              stringData = {
                "secrets.yaml" = config.age.secrets.matrix-mas-secrets-yaml.sopsRef;
                "encryption-key" = config.age.secrets.matrix-mas-encryption-key.sopsRef;
                "signing.key" = config.age.secrets.matrix-mas-signing-key.sopsRef;
                "shared-secret" = config.age.secrets.matrix-mas-shared-secret.sopsRef;
              };
            };

            ciliumNetworkPolicies = {
              allow-postgres-egress-mas = mkNetworkPolicy "Allow MAS to reach the matrix-pg CNPG cluster." {
                egress = [
                  {
                    toEndpoints = [ { matchLabels."cnpg.io/cluster" = "matrix-pg"; } ];
                    toPorts = [ { ports = [ (tcp 5432) ]; } ];
                  }
                ];
              };
              allow-gateway-ingress-mas =
                mkNetworkPolicy "Allow Envoy Gateway proxies and synapse to reach MAS."
                  {
                    ingress = [
                      {
                        fromEndpoints = [
                          { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                          { matchLabels."app.kubernetes.io/name" = "synapse"; }
                        ];
                        toPorts = [ { ports = [ (tcp port) ]; } ];
                      }
                    ];
                  };
              allow-synapse-egress-mas = mkNetworkPolicy "Allow MAS to provision users through Synapse." {
                egress = [
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "synapse"; } ];
                    toPorts = [ { ports = [ (tcp 8008) ]; } ];
                  }
                ];
              };
              allow-internet-egress-mas = mkNetworkPolicy "Allow MAS to reach kanidm." {
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

# synapse — the Matrix homeserver for server_name json64.dev, served at
# matrix.json64.dev (federation on 443 via .well-known delegation from the apex).
#
# server_name is PERMANENT: it is part of every user id, room alias and the
# federation signing identity. Do not change it without standing up a new server.
#
# Login is kanidm NATIVE OIDC (the romm pattern): Synapse runs the flow itself and
# the gateway only routes, because Matrix clients and federating servers must
# reach /_matrix unauthenticated. Password login and registration are disabled;
# accounts are created on first OIDC login for members of `matrix.access`. The one
# non-OIDC account is the @genie bot, created once with registration_shared_secret.
#
# Config is split in two files merged by Synapse (--config-path twice): the
# non-secret homeserver.yaml (ConfigMap, built here) and secrets.yaml (composed by
# a template-file age secret: macaroon/form/registration secrets and the database
# block, which has no *_path option for its password). The OIDC client secret and
# the signing key are mounted as files.
#
# /_synapse/admin is deliberately NOT routed: use `kubectl port-forward`.
{ lib, ... }:
let
  namespace = "matrix";
  port = 8008;
  uid = 991; # the matrixdotorg/synapse image's synapse user

  secretsTemplate = ''
    macaroon_secret_key: "%matrix-synapse-macaroon-secret-key%"
    form_secret: "%matrix-synapse-form-secret%"
    registration_shared_secret: "%matrix-synapse-registration-shared-secret%"
    database:
      name: psycopg2
      args:
        user: synapse
        password: "%matrix-pg-synapse-password%"
        dbname: synapse
        host: matrix-pg-rw.${namespace}.svc.cluster.local
        port: 5432
        sslmode: require
        cp_min: 5
        cp_max: 10
  '';

  mkNetworkPolicy = description: rule: {
    spec = {
      inherit description;
      endpointSelector.matchLabels."app.kubernetes.io/name" = "synapse";
    }
    // rule;
  };

  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
in
{
  den.aspects.kubernetes.services.communication.matrix.synapse = {
    service-domains = [ "matrix" ];

    age-secrets =
      { environment, config, ... }:
      {
        age.secrets = {
          synapse-oidc-client-secret = {
            rekeyFile = environment.secretPath + "/oidc/synapse-oidc-client-secret.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            sopsOutput = {
              file = "oidc";
              key = "synapse";
            };
          };
          matrix-synapse-macaroon-secret-key = {
            rekeyFile = environment.secretPath + "/matrix-synapse/macaroon-secret-key.age";
            generator.script = "rfc3986-secret";
          };
          matrix-synapse-form-secret = {
            rekeyFile = environment.secretPath + "/matrix-synapse/form-secret.age";
            generator.script = "rfc3986-secret";
          };
          matrix-synapse-registration-shared-secret = {
            rekeyFile = environment.secretPath + "/matrix-synapse/registration-shared-secret.age";
            generator.script = "rfc3986-secret";
          };
          # The federation identity. Losing it forces key rotation; back it up.
          matrix-synapse-signing-key = {
            rekeyFile = environment.secretPath + "/matrix-synapse/signing-key.age";
            generator.script = "synapse-signing-key";
            sopsOutput = {
              file = "matrix-synapse";
              key = "signing-key";
            };
          };
          matrix-synapse-secrets-yaml = {
            rekeyFile = environment.secretPath + "/matrix-synapse/secrets-yaml.age";
            generator.script = "template-file";
            generator.dependencies = [
              config.age.secrets.matrix-synapse-macaroon-secret-key
              config.age.secrets.matrix-synapse-form-secret
              config.age.secrets.matrix-synapse-registration-shared-secret
              config.age.secrets.matrix-pg-synapse-password
            ];
            settings.template = secretsTemplate;
            sopsOutput = {
              file = "matrix-synapse";
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
        images,
        ...
      }:
      let
        homeserver = {
          server_name = "json64.dev";
          public_baseurl = "https://${cluster.domainFor "matrix"}/";
          pid_file = "/data/homeserver.pid";
          listeners = [
            {
              inherit port;
              tls = false;
              type = "http";
              x_forwarded = true;
              bind_addresses = [ "0.0.0.0" ];
              resources = [
                {
                  names = [
                    "client"
                    "federation"
                  ];
                  compress = false;
                }
              ];
            }
          ];
          media_store_path = "/data/media_store";
          signing_key_path = "/secrets/signing.key";
          trusted_key_servers = [ { server_name = "matrix.org"; } ];
          suppress_key_server_warning = true;
          report_stats = false;
          max_upload_size = "50M";
          enable_registration = false;
          password_config.enabled = false;
          oidc_providers = [
            {
              idp_id = "kanidm";
              idp_name = "json64 (kanidm)";
              issuer = cluster.secrets.oidcIssuerFor "synapse";
              client_id = "synapse";
              client_secret_path = "/secrets/oidc-client-secret";
              scopes = [
                "openid"
                "profile"
                "email"
              ];
              pkce_method = "always";
              user_mapping_provider.config = {
                localpart_template = "{{ user.preferred_username }}";
                display_name_template = "{{ user.name }}";
                email_template = "{{ user.email }}";
              };
            }
          ];
        };
      in
      {
        applications.synapse = {
          inherit namespace;

          # Matrix delegation for server_name json64.dev, answered by Envoy itself on
          # the apex listener (json64-dev-apex-https; prod.nix `apex = true`): no pod,
          # and the json64.dev apex is not otherwise served by the cluster.
          objects =
            lib.mapAttrsToList
              (name: body: {
                apiVersion = "gateway.envoyproxy.io/v1alpha1";
                kind = "HTTPRouteFilter";
                metadata = {
                  name = "matrix-well-known-${name}";
                  inherit namespace;
                };
                spec.directResponse = {
                  statusCode = 200;
                  contentType = "application/json";
                  body = {
                    type = "Inline";
                    inline = builtins.toJSON body;
                  };
                  # Required by the client spec; harmless on the server document.
                  header.set = [
                    {
                      name = "Access-Control-Allow-Origin";
                      value = "*";
                    }
                  ];
                };
              })
              {
                server."m.server" = "${cluster.domainFor "matrix"}:443";
                client."m.homeserver".base_url = "https://${cluster.domainFor "matrix"}";
              };

          helm.releases.synapse = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              defaultPodOptions.securityContext = {
                runAsUser = uid;
                runAsGroup = uid;
                fsGroup = uid;
                fsGroupChangePolicy = "OnRootMismatch";
              };
              controllers.main = {
                type = "deployment";
                replicas = 1;
                strategy = "Recreate";
                containers.main = {
                  image = {
                    inherit (images."matrixdotorg/synapse") repository digest;
                  };
                  command = [
                    "python"
                    "-m"
                    "synapse.app.homeserver"
                  ];
                  args = [
                    "--config-path"
                    "/config/homeserver.yaml"
                    "--config-path"
                    "/secrets/secrets.yaml"
                  ];
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
              service.main = {
                controller = "main";
                ports.http.port = port;
              };
              persistence = {
                config = {
                  type = "configMap";
                  name = "synapse-config";
                  globalMounts = [ { path = "/config"; } ];
                };
                secrets = {
                  type = "secret";
                  name = "matrix-synapse";
                  globalMounts = [
                    {
                      path = "/secrets/secrets.yaml";
                      subPath = "secrets.yaml";
                      readOnly = true;
                    }
                    {
                      path = "/secrets/signing.key";
                      subPath = "signing.key";
                      readOnly = true;
                    }
                  ];
                };
                oidc = {
                  type = "secret";
                  name = "synapse-oidc-client-secret";
                  globalMounts = [
                    {
                      path = "/secrets/oidc-client-secret";
                      subPath = "client-secret";
                      readOnly = true;
                    }
                  ];
                };
                data = {
                  type = "persistentVolumeClaim";
                  existingClaim = "synapse-data";
                  globalMounts = [ { path = "/data"; } ];
                };
              };
            };
          };

          resources = {
            configMaps.synapse-config.data."homeserver.yaml" = builtins.toJSON homeserver;

            persistentVolumeClaims.synapse-data.spec = {
              accessModes = [ "ReadWriteOnce" ];
              storageClassName = "longhorn";
              resources.requests.storage = "20Gi";
            };

            secrets = {
              matrix-synapse = {
                type = "Opaque";
                stringData = {
                  "secrets.yaml" = config.age.secrets.matrix-synapse-secrets-yaml.sopsRef;
                  "signing.key" = config.age.secrets.matrix-synapse-signing-key.sopsRef;
                };
              };
              synapse-oidc-client-secret = {
                type = "Opaque";
                stringData.client-secret = config.age.secrets.synapse-oidc-client-secret.sopsRef;
              };
            };

            # Only the client and federation APIs are public. /_synapse/admin is
            # intentionally absent.
            httpRoutes.synapse.spec = {
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
                  matches = [
                    {
                      path = {
                        type = "PathPrefix";
                        value = "/_matrix";
                      };
                    }
                    {
                      path = {
                        type = "PathPrefix";
                        value = "/_synapse/client";
                      };
                    }
                  ];
                  backendRefs = [
                    {
                      name = "synapse";
                      inherit port;
                    }
                  ];
                }
              ];
            };

            httpRoutes.matrix-well-known.spec = {
              hostnames = [ "json64.dev" ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "matrix"}-apex-https";
                }
              ];
              rules =
                map
                  (doc: {
                    # Named: nixidy merges unnamed rules into one (rules is keyed by name).
                    name = doc;
                    matches = [
                      {
                        path = {
                          type = "Exact";
                          value = "/.well-known/matrix/${doc}";
                        };
                      }
                    ];
                    filters = [
                      {
                        type = "ExtensionRef";
                        extensionRef = {
                          group = "gateway.envoyproxy.io";
                          kind = "HTTPRouteFilter";
                          name = "matrix-well-known-${doc}";
                        };
                      }
                    ];
                  })
                  [
                    "server"
                    "client"
                  ];
            };

            ciliumNetworkPolicies = {
              allow-gateway-ingress-synapse = mkNetworkPolicy "Allow Envoy Gateway proxies to reach synapse." {
                ingress = [
                  {
                    fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };
              allow-dns-egress-synapse = mkNetworkPolicy "Allow synapse to resolve via kube-dns." {
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
                          (tcp 53)
                        ];
                      }
                    ];
                  }
                ];
              };
              allow-postgres-egress-synapse =
                mkNetworkPolicy "Allow synapse to reach the matrix-pg CNPG cluster."
                  {
                    egress = [
                      {
                        toEndpoints = [ { matchLabels."cnpg.io/cluster" = "matrix-pg"; } ];
                        toPorts = [ { ports = [ (tcp 5432) ]; } ];
                      }
                    ];
                  };
              # 443: kanidm (idm.json64.dev) and federation peers; 8448: federation
              # peers that do not delegate to 443.
              allow-internet-egress-synapse =
                mkNetworkPolicy "Allow synapse to reach kanidm and federation peers."
                  {
                    egress = [
                      {
                        toEntities = [ "world" ];
                        toPorts = [
                          {
                            ports = [
                              (tcp 443)
                              (tcp 8448)
                            ];
                          }
                        ];
                      }
                    ];
                  };
            };
          };
        };
      };
  };
}

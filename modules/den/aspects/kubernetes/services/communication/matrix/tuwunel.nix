# tuwunel — companion Matrix homeserver for server_name gen.wtf, served at
# matrix.gen.wtf, run beside Synapse (json64.dev) to compare the two.
#
# Single binary + embedded RocksDB on a Longhorn PVC; no Postgres. Login is kanidm
# OIDC (tuwunel's identity_provider), accounts created on first login for
# `matrix.access` members. Password registration is off.
#
# Delegation: the gen.wtf apex is GitHub Pages (sini/gen docs), not this cluster,
# so the /.well-known/matrix documents must be served there (or a
# _matrix-fed._tcp.gen.wtf SRV record used). Until then federation for gen.wtf
# does not resolve; clients can still use https://matrix.gen.wtf directly.
{ lib, ... }:
let
  namespace = "matrix";
  host = "matrix.gen.wtf";
  port = 8008;

  tomlConfig = ''
    [global]
    server_name = "gen.wtf"
    address = ["0.0.0.0"]
    port = ${toString port}
    database_path = "/data/db"
    allow_registration = false
    allow_federation = true
    trusted_servers = ["matrix.org"]
    max_request_size = 52428800

    [global.well_known]
    client = "https://${host}"
    server = "${host}:443"

    [[global.identity_provider]]
    brand = "kanidm"
    name = "json64 (kanidm)"
    client_id = "tuwunel"
    client_secret_file = "/secrets/oidc-client-secret"
    issuer_url = "https://idm.json64.dev/oauth2/openid/tuwunel"
    callback_url = "https://${host}/_matrix/client/unstable/login/sso/callback/tuwunel"
    scope = ["openid", "profile", "email"]
    userid_claims = ["preferred_username"]
    unique_id_fallbacks = false
    registration = true
    default = true
  '';

  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
  policy = description: rule: {
    spec = {
      inherit description;
      endpointSelector.matchLabels."app.kubernetes.io/name" = "tuwunel";
    }
    // rule;
  };
in
{
  den.aspects.kubernetes.services.communication.matrix.tuwunel = {
    # Resolves to `host` via prod services.tuwunel.domain (public DNS record).
    service-domains = [ "tuwunel" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.tuwunel-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/tuwunel-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "tuwunel";
          };
        };
      };

    k8s-manifests =
      {
        config,
        images,
        charts,
        ...
      }:
      {
        applications.tuwunel = {
          inherit namespace;

          helm.releases.tuwunel = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              # Upstream (docs/deploying/kubernetes.md): the first boot after an
              # upgrade may run a one-time DB migration with the listener closed;
              # a kill part-way leaves it half migrated. Generous grace period, and
              # a startup probe that holds off liveness/readiness until it serves.
              defaultPodOptions.terminationGracePeriodSeconds = 600;
              controllers.main = {
                type = "deployment";
                replicas = 1;
                strategy = "Recreate";
                containers.main = {
                  image = {
                    inherit (images."matrix-construct/tuwunel") repository digest;
                  };
                  args = [
                    "-c"
                    "/config/tuwunel.toml"
                  ];
                  probes =
                    lib.genAttrs [ "liveness" "readiness" ] (_: {
                      enabled = true;
                      custom = true;
                      spec.httpGet = {
                        path = "/_matrix/client/versions";
                        inherit port;
                      };
                    })
                    // {
                      startup = {
                        enabled = true;
                        custom = true;
                        spec = {
                          httpGet = {
                            path = "/_matrix/client/versions";
                            inherit port;
                          };
                          periodSeconds = 10;
                          failureThreshold = 180; # up to 30 minutes of migration
                        };
                      };
                    };
                };
              };
              service.main = {
                controller = "main";
                ports.http.port = port;
              };
              persistence = {
                config = {
                  type = "configMap";
                  name = "tuwunel-config";
                  globalMounts = [ { path = "/config"; } ];
                };
                oidc = {
                  type = "secret";
                  name = "tuwunel-oidc-client-secret";
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
                  existingClaim = "tuwunel-data";
                  globalMounts = [ { path = "/data"; } ];
                };
              };
            };
          };

          resources = {
            configMaps.tuwunel-config.data."tuwunel.toml" = tomlConfig;

            persistentVolumeClaims.tuwunel-data.spec = {
              accessModes = [ "ReadWriteOnce" ];
              storageClassName = "longhorn";
              resources.requests.storage = "20Gi";
            };

            secrets.tuwunel-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.tuwunel-oidc-client-secret.sopsRef;
            };

            # tuwunel serves the client/federation APIs and its own admin is in-band
            # (admin room), so the whole host is routed.
            httpRoutes.tuwunel.spec = {
              hostnames = [ host ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "gen-wtf-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "tuwunel";
                      inherit port;
                    }
                  ];
                }
              ];
            };

            ciliumNetworkPolicies = {
              allow-gateway-ingress-tuwunel = policy "Allow Envoy Gateway proxies to reach tuwunel." {
                ingress = [
                  {
                    fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };
              allow-dns-egress-tuwunel = policy "Allow tuwunel to resolve via kube-dns." {
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
              # 443: kanidm and federation peers; 8448: peers without delegation.
              allow-internet-egress-tuwunel = policy "Allow tuwunel to reach kanidm and federation peers." {
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

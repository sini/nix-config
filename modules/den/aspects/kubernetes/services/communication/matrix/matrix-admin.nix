# matrix-admin — Ketesa (formerly synapse-admin) plus the Synapse admin API on
# matrix-admin.json64.dev, behind Envoy gateway OIDC (kanidm `admins`).
#
# Two locks: the gateway admits only kanidm `admins`, and Synapse still requires
# an admin user's own access token on every /_synapse/admin call. Ketesa obtains
# that token by logging in through Synapse's kanidm SSO on this same origin
# (sso.client_whitelist in synapse.nix), so the admin API never appears on the
# public matrix.json64.dev host.
#
# forwardAccessToken stays false: the gateway must not overwrite the
# Authorization header, which carries the Synapse token.
{ lib, ... }:
let
  namespace = "matrix";
  port = 80;

  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
in
{
  den.aspects.kubernetes.services.communication.matrix.matrix-admin = {
    service-domains = [ "matrix-admin" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets.synapse-admin-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/synapse-admin-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "synapse-admin";
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
        host = cluster.domainFor "matrix-admin";
        ketesaConfig = {
          restrictBaseUrl = [ "https://${host}" ];
          externalAuthProvider = true;
        };
      in
      {
        applications.matrix-admin = {
          inherit namespace;

          helm.releases.matrix-admin = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";
                replicas = 1;
                containers.main = {
                  image = {
                    inherit (images."etkecc/ketesa") repository digest;
                  };
                  probes = lib.genAttrs [ "liveness" "readiness" ] (_: {
                    enabled = true;
                    custom = true;
                    spec.httpGet = {
                      path = "/";
                      inherit port;
                    };
                  });
                };
              };
              service.main = {
                controller = "main";
                ports.http.port = port;
              };
              persistence.config = {
                type = "configMap";
                name = "matrix-admin-config";
                globalMounts = [
                  {
                    path = "/var/public/config.json";
                    subPath = "config.json";
                    readOnly = true;
                  }
                ];
              };
            };
          };

          resources = {
            configMaps.matrix-admin-config.data."config.json" = builtins.toJSON ketesaConfig;

            # One host: the UI at /, the Synapse client and admin APIs beside it, so
            # Ketesa's SSO login and admin calls stay same-origin behind the gateway.
            httpRoutes.matrix-admin.spec = {
              hostnames = [ host ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "matrix-admin"}-https";
                }
              ];
              rules = [
                {
                  # Named: nixidy merges unnamed rules into one (rules is keyed by name).
                  name = "synapse";
                  matches =
                    map
                      (value: {
                        path = {
                          type = "PathPrefix";
                          inherit value;
                        };
                      })
                      [
                        "/_synapse/admin"
                        "/_synapse/client"
                        "/_matrix"
                      ];
                  backendRefs = [
                    {
                      name = "synapse";
                      port = 8008;
                    }
                  ];
                }
                {
                  name = "ui";
                  matches = [
                    {
                      path = {
                        type = "PathPrefix";
                        value = "/";
                      };
                    }
                  ];
                  backendRefs = [
                    {
                      name = "matrix-admin";
                      inherit port;
                    }
                  ];
                }
              ];
            };

            securityPolicies.matrix-admin-oidc.spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "matrix-admin";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "synapse-admin";
                clientID = "synapse-admin";
                clientSecret.name = "synapse-admin-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = false;
              };
            };

            secrets.synapse-admin-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.synapse-admin-oidc-client-secret.sopsRef;
            };

            ciliumNetworkPolicies.allow-gateway-ingress-matrix-admin.spec = {
              description = "Allow Envoy Gateway proxies to reach the Ketesa UI.";
              endpointSelector.matchLabels."app.kubernetes.io/name" = "matrix-admin";
              ingress = [
                {
                  fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; } ];
                  toPorts = [ { ports = [ (tcp port) ]; } ];
                }
              ];
            };
          };
        };
      };
  };
}

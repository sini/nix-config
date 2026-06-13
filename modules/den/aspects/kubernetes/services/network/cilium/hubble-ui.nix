# Hubble UI — Cilium network observability with OIDC protection.
{
  den.aspects.kubernetes.services.network.cilium.hubble-ui = {
    k8s-manifests =
      {
        config,
        cluster,
        ...
      }:
      {
        applications.cilium = {
          compareOptions.serverSideDiff = true;

          helm.releases.cilium.values.hubble = {
            enabled = true;
            relay = {
              enabled = true;
              rollOutPods = true;
            };
            ui = {
              enabled = true;
              rollOutPods = true;
            };
          };

          resources = {
            httpRoutes.hubble-ui.spec = {
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "hubble-ui"}-https";
                }
              ];
              hostnames = [ (cluster.domainFor "hubble-ui") ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "hubble-ui";
                      port = 80;
                    }
                  ];
                }
              ];
            };

            securityPolicies."hubble-ui-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "hubble-ui";
                }
              ];

              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "hubble-ui";
                clientID = "hubble-ui";
                clientSecret.name = "hubble-ui-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            secrets.hubble-ui-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.hubble-ui-oidc-client-secret.sopsRef;
            };

            ciliumNetworkPolicies = {
              allow-hubble-relay-server-egress.spec = {
                description = "Policy for egress from hubble relay to hubble server in Cilium agent.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "hubble-relay";
                egress = [
                  {
                    toEntities = [
                      "remote-node"
                      "host"
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "4244";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-hubble-ui-relay-ingress.spec = {
                description = "Policy for ingress from hubble UI to hubble relay.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "hubble-relay";
                ingress = [
                  {
                    fromEndpoints = [
                      {
                        matchLabels."app.kubernetes.io/name" = "hubble-ui";
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "4245";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-hubble-ui-kube-apiserver-egress.spec = {
                description = "Allow Hubble UI to talk to kube-apiserver";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "hubble-ui";
                egress = [
                  {
                    toEntities = [ "kube-apiserver" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-hubble-generate-certs-apiserver-egress.spec = {
                description = "Allow hubble-generate-certs job to talk to kube-apiserver.";
                endpointSelector.matchLabels.k8s-app = "hubble-generate-certs";
                egress = [
                  {
                    toEntities = [ "kube-apiserver" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6443";
                            protocol = "TCP";
                          }
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

    age-secrets =
      { environment, ... }:
      {
        age.secrets.hubble-ui-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/hubble-ui-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "hubble-ui";
          };
        };
      };
  };
}

{
  flake.kubernetes.services.hubble-ui = {
    nixidy =
      { environment, secrets, ... }:
      {
        applications.cilium = {

          compareOptions.serverSideDiff = true;

          helm.releases.cilium.values = {
            # Enable Hubble UI (Observability)
            hubble = {
              enabled = true;
              relay.enabled = true;
              relay.rollOutPods = true;
              ui.enabled = true;
              ui.rollOutPods = true;

              tls = {
                auto = {
                  enabled = true;
                  method = "cronJob";
                };
              };

            };
          };

          resources = {
            httpRoutes.hubble-ui.spec = {
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "kube-system";
                  sectionName = "https";
                }
              ];
              hostnames = [ "hubble.${environment.domain}" ];
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
                provider.issuer = "https://idm.${environment.domain}/oauth2/openid/hubble";
                clientID = "hubble";
                clientSecret.name = "hubble-oidc-client-secret";
                # cookieDomain = "${environment.domain}";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };

            };

            secrets.hubble-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = secrets.forOidcService "hubble";
            };

            ciliumNetworkPolicies = {
              # Allow hubble relay server egress to nodes
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

              # Allow hubble UI to talk to hubble relay
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

              # Allow hubble UI to talk to kube-apiserver
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

              # Allow hubble-generate-certs job to talk to kube-apiserver
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
  };
}

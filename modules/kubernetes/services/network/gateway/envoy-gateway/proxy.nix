{
  flake.kubernetes.services.envoy-gateway = {
    nixidy =
      {
        lib,
        environment,
        ...
      }:
      let
        default-gateway-address = environment.getAssignment "default-gateway";
        numReplicas = builtins.length (lib.attrValues (environment.findHostsByRole "kubernetes"));
        # Read certificate domains from environment configuration
        domains = environment.certificates.domains;
      in
      {
        applications.envoy-gateway-proxy = {
          namespace = "gateways";

          # Adoption-safe sync options
          syncPolicy = {
            syncOptions = {
              clientSideApplyMigration = false;
              serverSideApply = true;
            };
          };

          resources = {
            gateways.default-gateway.spec = {
              gatewayClassName = "envoy";
              infrastructure.parametersRef = {
                group = "gateway.envoyproxy.io";
                kind = "EnvoyProxy";
                name = "default-gateway-proxy-config";
              };
              listeners =
                domains
                |> builtins.attrNames
                |> map (
                  domain:
                  let
                    domainResourceName = environment.domainToResourceName domain;
                  in
                  [
                    {
                      name = "${domainResourceName}-http";
                      protocol = "HTTP";
                      port = 80;
                      hostname = "*.${domain}";
                      allowedRoutes.namespaces.from = "All";
                    }
                    {
                      name = "${domainResourceName}-https";
                      protocol = "HTTPS";
                      port = 443;
                      hostname = "*.${domain}";
                      allowedRoutes.namespaces.from = "All";
                      tls = {
                        mode = "Terminate";
                        certificateRefs = [
                          {
                            group = "";
                            kind = "Secret";
                            name = "${domainResourceName}-wildcard-tls";
                            namespace = "certs";
                          }
                        ];
                      };
                    }
                  ]
                )
                |> lib.flatten;
            };

            envoyProxies.default-gateway-proxy-config.spec = {
              provider = {
                type = "Kubernetes";
                kubernetes = {
                  envoyDeployment = {
                    replicas = numReplicas;
                    strategy.rollingUpdate = {
                      maxSurge = 1;
                    }
                    // lib.optionalAttrs (numReplicas == 1) {
                      maxUnavailable = 0;
                    };
                    pod.topologySpreadConstraints = [
                      {
                        maxSkew = 1;
                        topologyKey = "kubernetes.io/hostname";
                        whenUnsatisfiable = "DoNotSchedule";
                        labelSelector.matchLabels = {
                          "app.kubernetes.io/name" = "envoy";
                        };
                        matchLabelKeys = [
                          "pod-template-hash"
                          "gateway.envoyproxy.io/owning-gateway-name"
                          "gateway.envoyproxy.io/owning-gateway-namespace"
                        ];
                      }
                    ];
                  };
                  envoyService = {
                    type = "LoadBalancer";
                    annotations."lbipam.cilium.io/ips" = default-gateway-address;
                  };
                };
              };
            };

            referenceGrants.allow-kubesystem-gateway-to-cert-manager-tls = {
              metadata.namespace = "certs";
              spec = {
                from = [
                  {
                    group = "gateway.networking.k8s.io";
                    kind = "Gateway";
                    namespace = "gateways";
                  }
                ];
                to =
                  domains
                  |> builtins.attrNames
                  |> map (domain: {
                    group = "";
                    kind = "Secret";
                    name = "${environment.domainToResourceName domain}-wildcard-tls";
                  });
              };
            };

            ciliumNetworkPolicies = {
              # Allow gateway proxy pods in kube-system to reach external services (e.g., for OIDC token exchange)
              allow-gateway-world-egress = {
                metadata = {
                  namespace = "gateways";
                  annotations."argocd.argoproj.io/sync-wave" = "-1";
                };
                spec = {
                  endpointSelector.matchLabels."gateway.networking.k8s.io/gateway-name" = "default-gateway";
                  egress = [
                    {
                      toEntities = [
                        "world"
                      ];
                      toPorts = [
                        {
                          ports = [
                            {
                              port = "443";
                              protocol = "TCP";
                            }
                            {
                              port = "80";
                              protocol = "TCP";
                            }
                            {
                              port = "53";
                              protocol = "UDP";
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
  };
}

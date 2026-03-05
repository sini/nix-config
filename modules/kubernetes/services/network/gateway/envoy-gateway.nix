{
  flake.kubernetes.services.envoy-gateway = {
    crds =
      { inputs, system, ... }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.envoyproxy.gateway-crds-helm;
        extraOpts = [
          "--set crds.gatewayAPI.enabled=true"
          "--set crds.gatewayAPI.channel=experimental"
          "--set crds.envoyGateway.enabled=true"
        ];
      };

    nixidy =
      {
        lib,
        environment,
        charts,
        ...
      }:
      let
        gateway-controller-address = environment.getAssignment "gateway-controller";
        numReplicas = builtins.length (lib.attrValues (environment.findHostsByRole "kubernetes"));
        # Read certificate domains from environment configuration
        domains = environment.certificates.domains;
      in
      {
        applications.envoy-gateway = {
          namespace = "envoy-gateway-system";

          # Adoption-safe sync options
          syncPolicy = {
            syncOptions = {
              clientSideApplyMigration = false;
              serverSideApply = true;
            };
          };

          helm.releases.envoy = {
            chart = charts.envoyproxy.gateway-helm;

            includeCRDs = false;
            extraOpts = [ "--skip-crds" ];

            values = {
              deployment.replicas = 1;
              config = {
                envoyGateway = {
                  gateway.controllerName = "gateway.envoyproxy.io/gatewayclass-controller";
                  provider = {
                    type = "Kubernetes";
                    kubernetes.deploy.type = "GatewayNamespace";
                  };
                  extensionApis = {
                    enableEnvoyPatchPolicy = true;
                    enableBackend = true;
                  };
                  # rateLimit.backend = {
                  #   type = "Redis";
                  #   redis.url = "envoy-ratelimit-db.envoy-gateway-system.svc.cluster.local:6379";
                  # };

                };
              };
            };
          };

          resources = {
            gatewayClasses.envoy.spec.controllerName = "gateway.envoyproxy.io/gatewayclass-controller";

            gateways.default-gateway = {
              metadata.namespace = "kube-system";
              spec = {
                gatewayClassName = "envoy";
                infrastructure.parametersRef = {
                  group = "gateway.envoyproxy.io";
                  kind = "EnvoyProxy";
                  name = "envoy-proxy-config";
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
            };

            envoyProxies.envoy-proxy-config = {
              metadata.namespace = "kube-system";
              spec = {
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
                      annotations."lbipam.cilium.io/ips" = gateway-controller-address;
                    };
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
                    namespace = "kube-system";
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

              # Allow envoy gateway controller pods to reach external services
              allow-world-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "envoy-gateway-system";
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

              # Allow gateway proxy pods in kube-system to reach external services (e.g., for OIDC token exchange)
              allow-gateway-world-egress = {
                metadata = {
                  namespace = "kube-system";
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

              # Allow all envoy pods to access kube-apiserver
              allow-kube-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "envoy-gateway-system";
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

              allow-certgen-to-kube-apiserver-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  endpointSelector.matchLabels."job-name" = "envoy-gateway-helm-certgen";
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
  };
}

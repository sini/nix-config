{
  kubernetes.services.envoy-gateway = {
    crds =
      {
        inputs,
        system,
        ...
      }:
      {
        chart = inputs.nixhelm.chartsDerivations.${system}.envoyproxy.gateway-crds-helm;
        extraOpts = [
          "--set crds.gatewayAPI.enabled=true"
          "--set crds.gatewayAPI.channel=experimental"
          "--set crds.envoyGateway.enabled=true"
        ];
      };

    nixidy =
      { charts, ... }:
      {
        applications.envoy-gateway-system = {
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
                              port = "443";
                              protocol = "TCP";
                            }
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
                              port = "443";
                              protocol = "TCP";
                            }
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

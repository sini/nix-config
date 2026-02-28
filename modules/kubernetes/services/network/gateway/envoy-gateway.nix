{ self, ... }:
let
  inherit (self.lib.kubernetes-utils) findKubernetesNodes;
in
{
  flake.kubernetes.services.envoy-gateway = {
    crds =
      { pkgs, lib, ... }:
      let
        # nix run nixpkgs#nix-prefetch-github -- envoyproxy gateway --rev v1.7.0
        src = pkgs.fetchFromGitHub {
          owner = "envoyproxy";
          repo = "gateway";
          rev = "v1.7.0";
          hash = "sha256-SlEGwfLeE+utdcqlY//xAvQt89bh2y1GHN/whZZ3XHE=";
        };
        crds =
          let
            path = "charts/gateway-helm/crds/generated";
          in
          lib.pipe (builtins.readDir "${src}/${path}") [
            (lib.filterAttrs (_name: type: type == "regular"))
            (lib.filterAttrs (name: _type: lib.hasSuffix ".yaml" name))
            builtins.attrNames
            (map (file: "${path}/${file}"))
          ];
      in
      {
        inherit src crds;
      };

    nixidy =
      {
        lib,
        config,
        environment,
        ...
      }:
      let
        gateway-controller-address = config.kubernetes.loadBalancer.reservations.gateway-controller;
        numReplicas = builtins.length (lib.attrValues (findKubernetesNodes environment));
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
            chart = lib.helm.downloadHelmChart {
              repo = "oci://docker.io/envoyproxy";
              chart = "gateway-helm";
              version = "v1.7.0";
              chartHash = "sha256-JePGNofWs86ZVT1M6FI4Zg79BFvh2KudMnMOHjAbhJM=";
            };
            values = {
              deployment.replicas = numReplicas;
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
              metadata = {
                namespace = "kube-system";
              };
              spec = {
                gatewayClassName = "envoy"; # alt: cilium
                infrastructure.parametersRef = {
                  group = "gateway.envoyproxy.io";
                  kind = "EnvoyProxy";
                  name = "envoy-proxy-config";
                };
                # addresses = lib.toList {
                #   type = "IPAddress";
                #   value = gateway-controller-address;
                # };
                # infrastructure.annotations."external-dns.alpha.kubernetes.io/hostname" = "${name}.${domain}";
                listeners = [
                  {
                    name = "http";
                    protocol = "HTTP";
                    port = 80;
                    # hostname = "*.${environment.domain}";
                    allowedRoutes.namespaces.from = "All";
                  }
                  {
                    name = "https";
                    protocol = "HTTPS";
                    port = 443;
                    # hostname = "*.${environment.domain}";
                    allowedRoutes.namespaces.from = "All";
                    tls = {
                      mode = "Terminate";
                      certificateRefs = [
                        {
                          group = "";
                          kind = "Secret";
                          name = "wildcard-tls";
                          namespace = "security";
                        }
                      ];
                    };
                  }
                ];
              };
            };

            envoyProxies.envoy-proxy-config = {
              metadata.namespace = "kube-system";
              spec = {
                logging.level.default = "debug";
                provider = {
                  type = "Kubernetes";
                  kubernetes = {
                    envoyDeployment = {
                      replicas = numReplicas;
                      strategy.rollingUpdate = {
                        maxSurge = 1;
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

            referenceGrants.allow-kubesystem-gateway-to-wildcard-tls = {
              metadata.namespace = "security";
              spec = {
                from = [
                  {
                    group = "gateway.networking.k8s.io";
                    kind = "Gateway";
                    namespace = "kube-system";
                  }
                ];
                to = [
                  {
                    group = "";
                    kind = "Secret";
                    name = "wildcard-tls";
                  }
                ];
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

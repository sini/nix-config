# Envoy Gateway — Gateway API controller via envoyproxy/gateway-helm,
# experimental channel CRDs, EnvoyProxy config, default-gateway with
# per-domain HTTP/HTTPS listeners, CiliumNetworkPolicies.
#
# Ported from main:modules/kubernetes/services/network/gateway/envoy-gateway/
{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    flatten
    map
    optionalAttrs
    splitString
    take
    ;

  environments = config.den.environments;

  # Convert domain to k8s-safe resource name (last 2 parts, hyphenated)
  domainToResourceName =
    domain:
    let
      parts = splitString "." domain;
      topDomain = lib.reverseList (take 2 (lib.reverseList parts));
    in
    concatStringsSep "-" topDomain;
in
{
  den.aspects.kubernetes.services.network.gateway.envoy-gateway = {
    crds =
      { inputs, system, ... }:
      {
        name = "envoy-gateway";
        chart = inputs.nixhelm.chartsDerivations.${system}.envoyproxy.gateway-crds-helm;
        extraOpts = [
          "--set crds.gatewayAPI.enabled=true"
          "--set crds.gatewayAPI.channel=experimental"
          "--set crds.envoyGateway.enabled=true"
        ];
        # Sole owner of the Gateway API CRDs (experimental channel — a strict
        # superset of standard, and what the live cluster runs) plus the
        # Envoy-specific kinds; this module also generates the Gateway/HTTPRoute/
        # GatewayClass nixidy types. No kindFilter: the full set materializes in
        # bootstrap ahead of every consumer. The gateway-api aspect is NOT
        # included on the cluster — a second (standard-channel) copy duplicated
        # every shared kind and blocked the bootstrap sync
        # (RepeatedResourceWarning).
      };

    k8s-manifests =
      { cluster, charts, ... }:
      let
        environment = environments.${cluster.environment};
        numReplicas = if cluster.hosts != null then builtins.length cluster.hosts else 3;
        domains = environment.certificates.domains;
        default-gateway-address = cluster.getAssignment "default-gateway";
      in
      {
        # Envoy Gateway system controller
        applications.envoy-gateway-system = {
          namespace = "envoy-gateway-system";

          syncPolicy = {
            syncOptions = {
              clientSideApplyMigration = false;
              serverSideApply = true;
            };
          };

          helm.releases.envoy = {
            chart = charts.envoyproxy.gateway-helm;

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
                };
              };
            };
          };

          resources = {
            gatewayClasses.envoy.spec.controllerName = "gateway.envoyproxy.io/gatewayclass-controller";

            ciliumNetworkPolicies = {
              allow-world-egress = {
                metadata.annotations."argocd.argoproj.io/sync-wave" = "-1";
                spec = {
                  endpointSelector.matchLabels."k8s:io.kubernetes.pod.namespace" = "envoy-gateway-system";
                  egress = [
                    {
                      toEntities = [ "world" ];
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

        # Gateway proxy — per-domain listeners, EnvoyProxy config, ReferenceGrant
        applications.envoy-gateway-proxy = {
          namespace = "gateways";

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
                    domainResourceName = domainToResourceName domain;
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
                |> flatten;
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
                    // optionalAttrs (numReplicas == 1) {
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

            referenceGrants.allow-gateway-to-cert-tls = {
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
                    name = "${domainToResourceName domain}-wildcard-tls";
                  });
              };
            };

            ciliumNetworkPolicies = {
              allow-gateway-world-egress = {
                metadata = {
                  namespace = "gateways";
                  annotations."argocd.argoproj.io/sync-wave" = "-1";
                };
                spec = {
                  endpointSelector.matchLabels."gateway.networking.k8s.io/gateway-name" = "default-gateway";
                  egress = [
                    {
                      toEntities = [ "world" ];
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

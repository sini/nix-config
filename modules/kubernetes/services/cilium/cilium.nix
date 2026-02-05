{
  flake.kubernetes.services.cilium = {
    nixidy =
      {
        charts,
        environment,
        hosts,
        lib,
        ...
      }:
      let
        findClusterMaster =
          hosts:
          let
            masterHosts =
              hosts
              |> lib.attrsets.filterAttrs (
                hostname: hostConfig:
                (builtins.elem "kubernetes" (hostConfig.roles or [ ]))
                && (hostConfig.environment == environment.name)
              )
              |> lib.attrsets.filterAttrs (
                hostname: hostConfig: builtins.elem "kubernetes-master" (hostConfig.roles or [ ])
              );
          in
          if lib.length (lib.attrNames masterHosts) > 0 then
            let
              masterHost = lib.head (lib.attrValues masterHosts);
            in
            masterHost.tags.kubernetes-internal-ip or (builtins.head masterHost.ipv4)
          else
            null;
        masterIP = findClusterMaster hosts;
      in
      {
        applications.cilium = {
          namespace = "kube-system";

          compareOptions.serverSideDiff = true;

          helm.releases.cilium = {
            chart = charts.cilium.cilium;

            values = {
              # Cluster identity
              cluster = {
                name = environment.name;
                id = environment.id;
              };
              # Routing Mode
              routingMode = "tunnel";
              tunnelProtocol = "geneve";

              # Points to the stable loopback routed by the BGP fabric
              k8sServiceHost = masterIP;
              k8sServicePort = 6443;

              # Service handling / kube-proxy replacement
              kubeProxyReplacement = true;
              socketLB.hostNamespaceOnly = true;
              # localRedirectPolicies.enabled = true;
              # l2NeighDiscovery.enabled = false;

              hostPort.enabled = true;
              nodePort.enabled = true;

              # Datapath & BPF knobs
              # bpf = {
              #   masquerade = true;
              #   lbExternalClusterIP = true;
              #   hostLegacyRouting = true;
              # };

              # CNI chaining
              # cni.chainingMode = "portmap";

              # IPAM & Pod CIDRs
              # ipam = {
              #   mode = "cluster-pool";
              #   operator.clusterPoolIPv4PodCIDRList = [ environment.kubernetes.clusterCidr ];
              # };
              ipam.mode = "kubernetes";

              # Masquerading (SNAT) behavior
              enableIPv4 = true;
              ipv6.enabled = false;

              # enableIpMasqAgent = false;
              enableIPv4Masquerade = true;
              # nonMasqueradeCIDRs = "{10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}";
              # masqLinkLocal = false;

              # Device exposure to Cilium
              # With tunneling enabled, it is safe to manage both devices:
              # - 'dummy0': Used for sending/receiving VXLAN traffic over BGP fabric
              # - 'enp2s0': Used for BPF program handling ingress for ExternalIP services
              # devices = [
              #   "dummy0"
              #   "enp2s0"
              #   "enp199s0f5"
              #   "enp199s0f6"
              # ];

              # BGP control-plane (for FRR peering)
              # bgpControlPlane.enabled = true;

              # externalIPs.enabled = true;

              # loadBalancer.mode = "snat";

              # Hubble (observability)
              hubble = {
                enabled = true;
                relay.enabled = true;
                ui.enabled = true;
                metrics.enabled = [
                  "dns"
                  "drop"
                  "tcp"
                  "flow"
                  "port-distribution"
                  "icmp"
                  "http"
                ];
              };

              gatewayAPI.enabled = true;
              gatewayAPI.service = {
                enabled = true;
                type = "LoadBalancer";
                ports = [
                  {
                    name = "http";
                    port = 8080;
                  }
                  {
                    name = "https";
                    port = 8443;
                  }
                ];
              };

              # Operator & rollout
              operator.replicas = 2;
              rollOutCiliumPods = true;
              operator.rollOutPods = true;

              policyEnforcementMode = "always";
              policyAuditMode = false;

              encryption = {
                enabled = true;
                type = "wireguard";
              };
              # Logging
              # debug.enabled = true;
            };
          };

          resources = {
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

              # Allow kube-dns to talk to upstream DNS
              allow-kube-dns-upstream-egress.spec = {
                description = "Policy for egress to allow kube-dns to talk to upstream DNS.";
                endpointSelector.matchLabels.k8s-app = "kube-dns";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
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

              # Allow CoreDNS to talk to kube-apiserver
              allow-kube-dns-apiserver-egress.spec = {
                description = "Allow coredns to talk to kube-apiserver.";
                endpointSelector.matchLabels.k8s-app = "kube-dns";
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
                endpointSelector.matchLabels."batch.kubernetes.io/job-name" = "hubble-generate-certs";
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

            ciliumClusterwideNetworkPolicies = {
              # Allow all cilium endpoints to talk egress to each other
              allow-internal-egress.spec = {
                description = "Policy to allow all Cilium managed endpoint to talk to all other cilium managed endpoints on egress";
                endpointSelector = { };
                egress = [
                  {
                    toEndpoints = [ { } ];
                  }
                ];
              };

              # Allow all health checks
              cilium-health-checks.spec = {
                endpointSelector.matchLabels."reserved:health" = "";
                ingress = [
                  {
                    fromEntities = [ "remote-node" ];
                  }
                ];
                egress = [
                  {
                    toEntities = [ "remote-node" ];
                  }
                ];
              };

              # Allow all cilium managed endpoints to talk to cluster dns
              allow-kube-dns-cluster-ingress.spec = {
                description = "Policy for ingress allow to kube-dns from all Cilium managed endpoints in the cluster.";
                endpointSelector.matchLabels = {
                  "k8s:io.kubernetes.pod.namespace" = "kube-system";
                  "k8s-app" = "kube-dns";
                };
                ingress = [
                  {
                    fromEndpoints = [ { } ];
                    toPorts = [
                      {
                        ports = [
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
}

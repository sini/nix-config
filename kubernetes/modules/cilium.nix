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

        # Points to the stable loopback routed by the BGP fabric
        k8sServiceHost = masterIP;
        k8sServicePort = 6443;

        # Service handling / kube-proxy replacement
        kubeProxyReplacement = true;
        socketLB.hostNamespaceOnly = true;
        localRedirectPolicies.enabled = true;
        l2NeighDiscovery.enabled = false;

        # Datapath & BPF knobs
        bpf = {
          masquerade = true;
          lbExternalClusterIP = true;
          hostLegacyRouting = true;
        };

        # CNI chaining
        cni.chainingMode = "portmap";

        # IPAM & Pod CIDRs
        ipam = {
          mode = "cluster-pool";
          operator.clusterPoolIPv4PodCIDRList = [ "172.20.0.0/16" ];
        };

        # Routing Mode
        routingMode = "tunnel";
        tunnelProtocol = "geneve";

        # Masquerading (SNAT) behavior
        enableIPv4 = true;
        enableIpMasqAgent = false;
        enableIPv4Masquerade = true;
        nonMasqueradeCIDRs = "{10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}";
        masqLinkLocal = false;

        # Device exposure to Cilium
        # With tunneling enabled, it is safe to manage both devices:
        # - 'dummy0': Used for sending/receiving VXLAN traffic over BGP fabric
        # - 'enp2s0': Used for BPF program handling ingress for ExternalIP services
        devices = [
          "dummy0"
          "enp2s0"
          "enp199s0f5"
          "enp199s0f6"
        ];

        # BGP control-plane (for FRR peering)
        bgpControlPlane.enabled = true;

        externalIPs.enabled = true;

        loadBalancer.mode = "snat";

        # Hubble (observability)
        hubble = {
          enabled = true;
          relay.enabled = true;
          ui.enabled = true;
        };

        # Operator & rollout
        operator.replicas = 2;
        rollOutCiliumPods = true;

        # Logging
        debug.enabled = true;
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

      # Shared peer configuration for all nodes
      ciliumBGPPeerConfigs = {
        local-frr-peer.spec = {
          ebgpMultihop = 4;
          timers = {
            connectRetryTimeSeconds = 5;
            holdTimeSeconds = 30;
            keepAliveTimeSeconds = 10;
          };
          families = [
            {
              afi = "ipv4";
              safi = "unicast";
              advertisements.matchLabels."advertise" = "cilium-routes";
            }
          ];
        };
      };

      # BGP Cluster Configurations for each node
      ciliumBGPClusterConfigs = {
        cilium-bgp-axon-01.spec = {
          nodeSelector.matchLabels."kubernetes.io/hostname" = "axon-01";
          bgpInstances = [
            {
              name = "local-frr-instance";
              localASN = 65001;
              peers = [
                {
                  name = "local-frr-daemon";
                  peerASN = 65001;
                  peerAddress = "172.16.255.1";
                  peerConfigRef.name = "local-frr-peer";
                }
              ];
            }
          ];
        };

        cilium-bgp-axon-02.spec = {
          nodeSelector.matchLabels."kubernetes.io/hostname" = "axon-02";
          bgpInstances = [
            {
              name = "local-frr-instance";
              localASN = 65002;
              peers = [
                {
                  name = "local-frr-daemon";
                  peerASN = 65002;
                  peerAddress = "172.16.255.2";
                  peerConfigRef.name = "local-frr-peer";
                }
              ];
            }
          ];
        };

        cilium-bgp-axon-03.spec = {
          nodeSelector.matchLabels."kubernetes.io/hostname" = "axon-03";
          bgpInstances = [
            {
              name = "local-frr-instance";
              localASN = 65003;
              peers = [
                {
                  name = "local-frr-daemon";
                  peerASN = 65003;
                  peerAddress = "172.16.255.3";
                  peerConfigRef.name = "local-frr-peer";
                }
              ];
            }
          ];
        };
      };

      # BGP Advertisements
      ciliumBGPAdvertisements = {
        pod-cidr-advertisement = {
          metadata.labels.advertise = "cilium-routes";
          spec.advertisements = [
            { advertisementType = "PodCIDR"; }
          ];
        };

        service-cluster-ips = {
          metadata.labels.advertise = "cilium-routes";
          spec.advertisements = [
            {
              advertisementType = "Service";
              service.addresses = [ "ClusterIP" ];
              selector.matchExpressions = [
                {
                  key = "service.kubernetes.io/headless";
                  operator = "DoesNotExist";
                }
              ];
            }
          ];
        };

        loadbalancer-ips = {
          metadata.labels.advertise = "cilium-routes";
          spec.advertisements = [
            {
              advertisementType = "Service";
              service.addresses = [
                "LoadBalancerIP"
                "ExternalIP"
              ];
              selector.matchExpressions = [
                {
                  key = "service.kubernetes.io/headless";
                  operator = "DoesNotExist";
                }
              ];
            }
          ];
        };
      };

      # LoadBalancer IP Pool
      ciliumLoadBalancerIPPools = {
        main-lb-pool.spec = {
          blocks = [ { cidr = "10.11.0.0/16"; } ];
          serviceSelector.matchLabels = { };
        };
      };

      # Node-specific router ID overrides
      ciliumBGPNodeConfigOverrides = {
        axon-01 = {
          metadata.name = "axon-01";
          spec.bgpInstances = [
            {
              name = "local-frr-instance";
              routerID = "172.16.255.11";
            }
          ];
        };

        axon-02 = {
          metadata.name = "axon-02";
          spec.bgpInstances = [
            {
              name = "local-frr-instance";
              routerID = "172.16.255.12";
            }
          ];
        };

        axon-03 = {
          metadata.name = "axon-03";
          spec.bgpInstances = [
            {
              name = "local-frr-instance";
              routerID = "172.16.255.13";
            }
          ];
        };
      };

      # # Ingress route for Hubble UI
      # ingressRoutes = {
      #   cilium-dashboard-route.spec = {
      #     entryPoints = [ "websecure" ];
      #     routes = [
      #       {
      #         match = "Host(`cni.json64.dev`)";
      #         kind = "Rule";
      #         services = [
      #           {
      #             name = "hubble-ui";
      #             namespace = "kube-system";
      #             port = 80;
      #           }
      #         ];
      #       }
      #     ];
      #     tls.secretName = "anderwersede-tls-certificate";
      #   };
      # };
    };
  };
}

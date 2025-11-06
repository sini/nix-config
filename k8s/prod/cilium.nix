{ charts, ... }:
{
  applications.cilium = {
    namespace = "kube-system";

    compareOptions.serverSideDiff = true;

    helm.releases.cilium = {
      chart = charts.cilium.cilium;

      values = {
        # Cluster identity
        cluster = {
          name = "prod";
          id = 1;
        };

        # Each node in a k3s cluster runs a local
        # load balancer for the API server on port
        # 6444.
        k8sServiceHost = "localhost";
        k8sServicePort = 6444;

        # Service handling / kube-proxy replacement
        kubeProxyReplacement = true;
        localRedirectPolicies.enabled = true;
        l2NeighDiscovery.enabled = false;

        # Datapath & BPF knobs
        bpf = {
          masquerade = true;
          lbExternalClusterIP = true;
          hostLegacyRouting = true;
          vlanBypass = [ 0 ];
        };

        # IPAM & Pod CIDRs
        ipam = {
          mode = "cluster-pool";
          operator.clusterPoolIPv4PodCIDRList = [ "172.20.0.0/16" ];
        };

        # Routing Mode
        routingMode = "tunnel";
        tunnelProtocol = "geneve";

        loadBalancer = {
          mode = "dsr";
          dsrDispatch = "geneve";
        };

        # Masquerading (SNAT) behavior
        enableIPv4 = true;
        enableIpMasqAgent = true;
        enableIPv4Masquerade = true;
        enableMasqueradeToRouteSource = true;
        nonMasqueradeCIDRs = "{10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}";
        masqLinkLocal = true;

        # BGP control-plane (for FRR peering)
        bgpControlPlane.enabled = true;

        externalIPs.enabled = true;

        nodePort = {
          enabled = true;
          directRoutingDevice = "bond0";
        };

        # Hubble (observability)
        hubble = {
          relay.enabled = true;
          ui.enabled = true;
          # This should be used so the rendered manifest
          # doesn't contain TLS secrets.
          tls.auto.method = "cronJob";
        };

        # Operator & rollout
        operator.replicas = 2;
        rollOutCiliumPods = true;

        # Logging
        debug.enabled = false;
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

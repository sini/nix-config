{ lib, ... }:
{
  flake.kubernetes.services.cilium = {
    crds =
      { pkgs, lib, ... }:
      let
        # nix run nixpkgs#nix-prefetch-github -- cilium cilium --rev v1.19.1
        # NOTE: Remember to keep pkgs/by-name/cni-plugin-cilium in sync
        src = pkgs.fetchFromGitHub {
          owner = "cilium";
          repo = "cilium";
          rev = "v1.19.1";
          hash = "sha256-wswY4u2Z7Z8hvGVnLONxSD1Mu1RV1AglC4ijUHsCCW4=";
        };
        crds =
          lib.concatMap
            (
              version:
              let
                path = "pkg/k8s/apis/cilium.io/client/crds/${version}";
              in
              lib.pipe (builtins.readDir "${src}/${path}") [
                (lib.filterAttrs (_name: type: type == "regular"))
                (lib.filterAttrs (name: _type: lib.hasSuffix ".yaml" name))
                builtins.attrNames
                (map (file: "${path}/${file}"))
              ]
            )
            [
              "v2"
              "v2alpha1"
            ];
      in
      {
        inherit src crds;
      };

    options = {
      devices = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "List of devices";
      };
      directRoutingDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default routing device";
      };
    };

    nixidy =
      {
        config,
        charts,
        environment,
        ...
      }:
      let
        # Find networks by purpose
        findNetworkByPurpose =
          purpose: lib.findFirst (net: net.purpose == purpose) null (lib.attrValues environment.networks);

        podNetwork = findNetworkByPurpose "kubernetes-pods";
        # serviceNetwork = findNetworkByPurpose "kubernetes-services";
        loadbalancerNetwork = findNetworkByPurpose "loadbalancer";

        loadbalancer-cidr = loadbalancerNetwork.cidr;
        # ingress-controller-address = environment.getAssignment "cilium-ingress-controller";
      in
      {
        applications.cilium = {
          namespace = "kube-system";

          annotations."argocd.argoproj.io/sync-wave" = "-2";

          syncPolicy = {
            autoSync = {
              enable = false;
              prune = true;
              selfHeal = true;
            };
            syncOptions = {
              serverSideApply = true;
              applyOutOfSyncOnly = true;
            };
          };

          compareOptions.serverSideDiff = true;

          helm.releases.cilium = {
            chart = charts.cilium.cilium;

            values = {
              namespaceOverride = "kube-system";

              # Cluster identity
              cluster = {
                name = environment.name;
                id = environment.id;
              };

              # Routing Mode
              # routingMode = "native";
              ipv4NativeRoutingCIDR = podNetwork.cidr;
              ipv6NativeRoutingCIDR = podNetwork.ipv6_cidr;
              routingMode = "tunnel";
              tunnelProtocol = "geneve";

              # endpointRoutes.enabled = true;

              devices = lib.mkIf (
                config.kubernetes.services.cilium.devices != null
              ) config.kubernetes.services.cilium.devices;

              nodePort = lib.optionalAttrs (config.kubernetes.services.cilium.directRoutingDevice != null) {
                directRoutingDevice = config.kubernetes.services.cilium.directRoutingDevice;
              };
              # egress-masquerade-interfaces:

              # Points to the stable loopback routed by the BGP fabric
              k8sServiceHost = environment.getAssignment "kube-apiserver-vip";
              k8sServicePort = 6443;

              # Set Cilium as a kube-proxy replacement.
              kubeProxyReplacement = true;
              localRedirectPolicies.enabled = true;
              # autoDirectNodeRoutes = true;

              # Roll out when config changes
              rollOutCiliumPods = true;

              externalIPs.enabled = true;

              # ingressController = {
              #   enabled = true;
              #   default = true;
              #   loadbalancerMode = "shared";
              #   # hostNetwork.enabled = true;
              #   defaultSecretNamespace = "kube-system";
              #   defaultSecretName = "wildcard-tls";
              #   service = {
              #     annotations = {
              #       "lbipam.cilium.io/ips" = ingress-controller-address;
              #       "lbipam.cilium.io/sharing-key" = "cilium-ingress";
              #     };
              #   };
              # };

              ipv6.enabled = true;

              gatewayAPI.enabled = false; # Trying out envoy...
              gatewayAPI.hostNetwork.enabled = false;

              # Explicitly enable Envoy...
              envoy.enabled = false; # Trying out envoy...
              envoy.rollOutPods = true;

              # Don't create secretsNamespace, we do this in the bootstrap app
              tls.secretsNamespace.create = false;
              ingressController.secretsNamespace.create = false;
              gatewayAPI.secretsNamespace.create = false;
              envoyConfig.secretsNamespace.create = false;

              k8sClientRateLimit = {
                qps = 50;
                burst = 200;
              };

              operator = {
                enabled = true;
                replicas = 1;
                rollOutPods = true;
              };

              # Needed for the tailscale proxy setup to work.
              socketLB.hostNamespaceOnly = true;
              bpf.hostLegacyRouting = true;
              bpf.lbExternalClusterIP = true;
              bpf.lbSourceRangeAllTypes = true;
              bpf.masquerade = true;
              bpf.disableExternalIPMitigation = true;
              # bpf.tproxy = true;
              # bpf.datapathMode = "netkit";

              # ipMasqAgent = {
              #   enabled = true;
              #   config.nonMasqueradeCIDRs = "{${podNetwork.cidr},${serviceNetwork.cidr},${podNetwork.ipv6_cidr},${serviceNetwork.ipv6_cidr},${managementNetwork.cidr},${managementNetwork.ipv6_cidr}}";
              #   config.masqLinkLocal = false;
              # };

              # loadBalancer.acceleration = "best-effort";
              # loadBalancer.mode = "dsr";
              # loadBalancer.dsrDispatch = "geneve";

              # IPAM & Pod CIDRs
              ipam = {
                mode = "cluster-pool";
                operator = {
                  clusterPoolIPv4PodCIDRList = [ podNetwork.cidr ];
                  clusterPoolIPv4MaskSize = 24;
                  clusterPoolIPv6PodCIDRList = [ podNetwork.ipv6_cidr ];
                  clusterPoolIPv6MaskSize = 112;
                };
              };

              # BGP control-plane (for FRR peering)
              bgpControlPlane.enabled = true;

              # We announce via BGP
              # l2announcements.enabled = true;
              # l2NeighDiscovery.enabled = true;

              policyEnforcementMode = "default";
              policyAuditMode = false;
            };
          };

          resources = {

            ciliumLoadBalancerIPPools."lb-pool" = {
              metadata = {
                name = "lb-pool";
              };
              spec = {
                blocks = [ { cidr = loadbalancer-cidr; } ];
              };
            };

            # Disabled in favor of BGP -> FRR
            # ciliumL2AnnouncementPolicies."default-l2-announcement-policy" = {
            #   metadata = {
            #     name = "default-l2-announcement-policy";
            #     namespace = "kube-system";
            #   };
            #   spec = {
            #     externalIPs = true;
            #     loadBalancerIPs = true;
            #   };
            # };

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
            };
          };
        };
      };
  };
}

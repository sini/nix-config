# Cilium CNI — geneve tunnel, kube-proxy replacement, BGP control-plane,
# BPF masquerade, IPAM cluster-pool, socket LB, CiliumNetworkPolicies.
#
# Ported from main:modules/kubernetes/services/network/cilium/cilium.nix
{
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.kubernetes.services.network.cilium = {
    crds =
      { pkgs, lib, ... }:
      let
        # Reuse the cni plugin's pinned cilium checkout so the CRDs track the
        # same version as the agent, with the GitHub source declared once (in
        # pkgs/by-name/cni-plugin-cilium, bumped via `update-pkgs`). pkgs.local
        # is provided by the flake's default overlay (see policies/clusters.nix).
        src = pkgs.local.cni-plugin-cilium.src;
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
        name = "cilium";
        inherit src crds;
      };

    k8s-manifests =
      { cluster, charts, ... }:
      let
        environment = environments.${cluster.environment};
        podNetwork = cluster.networks.kubernetes-pods;
        loadbalancerNetwork = cluster.networks.kubernetes-loadbalancers;
        loadbalancer-cidr = loadbalancerNetwork.cidr;
      in
      {
        applications.cilium = {
          namespace = "kube-system";

          annotations."argocd.argoproj.io/sync-wave" = "-2";

          syncPolicy = {
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
                inherit (environment) name;
                inherit (environment) id;
              };

              # Routing — geneve tunnel. MTU stays auto-detected: an explicit
              # MTU is the BASE device MTU (cilium subtracts the geneve
              # overhead itself), so the old `MTU = 1450` double-subtracted —
              # pods routed at 1400 and the datapath emitted frag-needed for
              # any >1450 host flow, stalling GRO-coalesced kubelet/apiserver
              # replies across the thunderbolt mesh in an ICMP storm.
              ipv4NativeRoutingCIDR = podNetwork.cidr;
              ipv6NativeRoutingCIDR = podNetwork.ipv6_cidr;
              routingMode = "tunnel";
              tunnelProtocol = "geneve";

              # Stable loopback routed by BGP fabric
              k8sServiceHost = "localhost";
              k8sServicePort = 6443;

              # Kube-proxy replacement
              kubeProxyReplacement = true;
              localRedirectPolicies.enabled = true;

              rollOutCiliumPods = true;

              externalIPs.enabled = true;

              ipv6.enabled = true;

              gatewayAPI = {
                enabled = false;
                hostNetwork.enabled = false;
                secretsNamespace.create = false;
              };

              envoy = {
                enabled = false;
                rollOutPods = true;
              };

              hubble = {
                tls = {
                  auto = {
                    enabled = true;
                    method = "cronJob";
                  };
                };
              };

              tls.secretsNamespace.create = false;
              ingressController.secretsNamespace.create = false;
              envoyConfig.secretsNamespace.create = false;

              operator = {
                enabled = true;
                replicas = 1;
                rollOutPods = true;
              };

              # Socket LB + BPF masquerade
              socketLB.hostNamespaceOnly = true;
              bpf = {
                hostLegacyRouting = true;
                lbExternalClusterIP = true;
                lbSourceRangeAllTypes = true;
                masquerade = true;
                disableExternalIPMitigation = true;
              };

              # IPAM cluster-pool with pod CIDR from cluster
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

              policyEnforcementMode = "default";
              policyAuditMode = false;
            };
          };

          resources = {
            ciliumLoadBalancerIPPools."lb-pool" = {
              metadata.name = "lb-pool";
              spec.blocks = [ { cidr = loadbalancer-cidr; } ];
            };

            ciliumClusterwideNetworkPolicies = {
              # Allow all cilium endpoints egress to each other
              allow-internal-egress.spec = {
                description = "Policy to allow all Cilium managed endpoint to talk to all other cilium managed endpoints on egress";
                endpointSelector = { };
                egress = [
                  { toEndpoints = [ { } ]; }
                ];
              };

              # Allow all health checks
              cilium-health-checks.spec = {
                endpointSelector.matchLabels."reserved:health" = "";
                ingress = [
                  { fromEntities = [ "remote-node" ]; }
                ];
                egress = [
                  { toEntities = [ "remote-node" ]; }
                ];
              };
            };
          };
        };
      };
  };
}

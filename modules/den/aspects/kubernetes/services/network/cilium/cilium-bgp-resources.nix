# Cilium BGP CRDs — BGPAdvertisements (Service ExternalIP + LoadBalancerIP),
# BGPPeerConfigs (EBGP multihop 4, timers), BGPClusterConfigs per host.
#
# Consumes k3s-nodes pipe data collected at cluster scope via pipe.collectAll.
{ lib, ... }:
let
  inherit (lib)
    listToAttrs
    ;
in
{
  den.aspects.kubernetes.services.network.cilium.cilium-bgp-resources = {
    k8s-manifests =
      { cluster, k3s-nodes, ... }:
      let
        clusterNodes = lib.filter (n: n.environment.name == cluster.environment) k3s-nodes;
      in
      {
        applications.cilium = {
          namespace = "kube-system";

          resources = {
            ciliumBGPAdvertisements = {
              loadbalancer-ips = {
                metadata.labels.advertise = "cilium-routes";
                spec.advertisements = [
                  {
                    advertisementType = "Service";
                    service.addresses = [
                      "ExternalIP"
                      "LoadBalancerIP"
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

            ciliumBGPPeerConfigs = {
              "cilium-bgp".spec = {
                ebgpMultihop = 4;
                timers = {
                  connectRetryTimeSeconds = 5;
                  holdTimeSeconds = 30;
                  keepAliveTimeSeconds = 10;
                };
                gracefulRestart = {
                  enabled = true;
                  restartTimeSeconds = 15;
                };
                families = [
                  {
                    afi = "ipv4";
                    safi = "unicast";
                    advertisements.matchLabels.advertise = "cilium-routes";
                  }
                ];
              };
            };

            ciliumBGPNodeConfigOverrides = listToAttrs (
              map (node: {
                name = node.hostname;
                value.spec.bgpInstances = [
                  { name = "local-frr-instance"; }
                ];
              }) clusterNodes
            );

            ciliumBGPClusterConfigs = listToAttrs (
              map (node: {
                name = "cilium-bgp-${node.hostname}";
                value.spec = {
                  nodeSelector.matchLabels = {
                    "kubernetes.io/hostname" = node.hostname;
                  };
                  bgpInstances = [
                    {
                      name = "local-frr-instance";
                      localASN = node.ciliumBgpLocalAsn;
                      peers = [
                        {
                          name = "local-frr-daemon";
                          peerASN = node.bgpLocalAsn;
                          peerAddress = node.ip;
                          peerConfigRef.name = "cilium-bgp";
                        }
                      ];
                    }
                  ];
                };
              }) clusterNodes
            );
          };
        };
      };
  };
}

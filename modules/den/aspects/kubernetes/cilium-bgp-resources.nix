# Cilium BGP CRDs — BGPAdvertisements (Service ExternalIP + LoadBalancerIP),
# BGPPeerConfigs (EBGP multihop 4, timers), BGPClusterConfigs per host.
#
# Ported from main:modules/kubernetes/services/network/cilium/cilium-bgp.nix
{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    filterAttrs
    head
    mapAttrs'
    ;

  allHosts = config.den.hosts.x86_64-linux or { };
in
{
  den.aspects.kubernetes.cilium-bgp-resources = {
    k8s-manifests =
      { cluster, ... }:
      let
        clusterHosts = filterAttrs (
          _: h: h.environment == cluster.environment && (h.settings.services.k3s or { }) != { }
        ) allHosts;
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

            ciliumBGPNodeConfigOverrides =
              clusterHosts
              |> mapAttrs' (
                hostname: _hostConfig: {
                  name = hostname;
                  value = {
                    spec.bgpInstances = [
                      { name = "local-frr-instance"; }
                    ];
                  };
                }
              );

            ciliumBGPClusterConfigs =
              clusterHosts
              |> mapAttrs' (
                hostname: hostConfig: {
                  name = "cilium-bgp-${hostname}";
                  value = {
                    spec = {
                      nodeSelector.matchLabels = {
                        "kubernetes.io/hostname" = hostname;
                      };
                      bgpInstances = [
                        {
                          name = "local-frr-instance";
                          localASN = hostConfig.settings.services.cilium-bgp.localAsn;
                          peers = [
                            {
                              name = "local-frr-daemon";
                              peerASN = hostConfig.settings.services.bgp.localAsn;
                              peerAddress = head hostConfig.ipv4;
                              peerConfigRef.name = "cilium-bgp";
                            }
                          ];
                        }
                      ];
                    };
                  };
                }
              );
          };
        };
      };
  };
}

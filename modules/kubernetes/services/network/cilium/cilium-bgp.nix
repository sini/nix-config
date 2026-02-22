{ self, ... }:
let
  inherit (self.lib.kubernetes-utils) findKubernetesNodes;
in
{
  flake.kubernetes.services.cilium-bgp = {
    nixidy =
      { environment, lib, ... }:
      let
        hosts = findKubernetesNodes environment;
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
                      "ClusterIP"
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
              service-cluster-ips = {
                metadata.labels.advertise = "cilium-routes";
                spec.advertisements = [
                  {
                    advertisementType = "Service";
                    service.addresses = [
                      "ClusterIP"
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
              pod-cidr-advertisement = {
                metadata.labels.advertise = "cilium-routes";
                spec.advertisements = [ { advertisementType = "PodCIDR"; } ];
              };
            };

            ciliumBGPPeerConfigs = {
              "local-frr-peer".spec = {
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
                    advertisements.matchLabels.advertise = "cilium-routes";
                  }
                ];
              };
            };

            ciliumBGPNodeConfigOverrides =
              hosts
              |> lib.attrsets.mapAttrs' (
                hostname: hostConfig: {
                  name = hostname;
                  value = {
                    spec.bgpInstances = [
                      {
                        name = "local-frr-instance";
                        routerID = hostConfig.tags.kubernetes-cilium-bgp-id;
                      }
                    ];
                  };
                }
              );

            ciliumBGPClusterConfigs =
              hosts
              |> lib.attrsets.mapAttrs' (
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
                          localASN = lib.toInt hostConfig.tags.bgp-asn;
                          peers = [
                            {
                              name = "local-frr-daemon";
                              peerASN = lib.toInt hostConfig.tags.bgp-asn;
                              peerAddress = hostConfig.tags.kubernetes-internal-ip;
                              peerConfigRef.name = "local-frr-peer";
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

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
                      # "ClusterIP"
                      # "ExternalIP"
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
              hosts
              |> lib.attrsets.mapAttrs' (
                hostname: hostConfig: {
                  name = hostname;
                  value = {
                    spec.bgpInstances = [
                      {
                        name = "local-frr-instance";
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
                          localASN = lib.toInt hostConfig.tags.cilium-asn;
                          peers = [
                            {
                              name = "local-frr-daemon";
                              peerASN = lib.toInt hostConfig.tags.bgp-asn;
                              peerAddress = builtins.head hostConfig.ipv4; # "127.0.0.1";
                              peerConfigRef.name = "cilium-bgp";
                            }
                            # {
                            #   name = "uplink-frr-daemon";
                            #   peerASN = 65000;
                            #   peerAddress = "10.10.10.1"; # "127.0.0.1";
                            #   peerConfigRef.name = "cilium-bgp";
                            # }
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

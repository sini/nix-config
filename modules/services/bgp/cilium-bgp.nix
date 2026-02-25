# Cilium BGP configuration for Kubernetes clusters
# Handles BGP peering with Cilium for pod/service CIDR advertisement
{
  config,
  lib,
  ...
}:
let
  # Find the bgp-hub host in the same environment
  findBgpHub =
    currentHostEnvironment:
    let
      bgpHubHosts = lib.mapAttrsToList (hostname: hostConfig: builtins.head hostConfig.ipv4) (
        lib.attrsets.filterAttrs (
          hostname: hostConfig:
          builtins.elem "bgp-hub" hostConfig.roles && hostConfig.environment == currentHostEnvironment
        ) config.flake.hosts
      );
    in
    if bgpHubHosts != [ ] then lib.head bgpHubHosts else null;
in
{
  flake.features.cilium-bgp = {
    requires = [ "bgp-core" ];
    nixos =
      {
        lib,
        environment,
        hostOptions,
        ...
      }:
      let
        nodeLoopbackIp = builtins.head hostOptions.ipv4;

        # Get local ASN from host tags or use default
        localAsn =
          if hostOptions.tags ? "bgp-asn" then
            lib.toInt hostOptions.tags."bgp-asn"
          else
            # Default logic for nodes without specific ASN
            65001;

        ciliumAsn =
          if hostOptions.tags ? "cilium-asn" then
            lib.toInt hostOptions.tags."cilium-asn"
          else
            # Default logic for nodes without specific ASN
            65002;

        uplinkIp = findBgpHub hostOptions.environment;
      in
      {
        config = {
          services.bgp = {
            localAsn = localAsn;
            routerId = nodeLoopbackIp;

            prefixLists = {
              CILIUM-ROUTES = [
                "permit ${environment.kubernetes.clusterCidr} le 32"
                "permit ${environment.kubernetes.serviceCidr} le 32"
                "permit ${environment.kubernetes.loadBalancer.cidr} le 32"
              ];
              DEFAULT-ONLY = [
                "permit 0.0.0.0/0"
              ];
            };

            routeMaps = [
              "route-map CILIUM-INGRESS-FIX permit 10"
              "  match ip address prefix-list CILIUM-ROUTES"
              # "  set ip next-hop ${nodeLoopbackIp}"
              "route-map FROM-UPLINK-IN permit 10"
              "  match ip address prefix-list DEFAULT-ONLY"
            ];

            peerGroups.cilium = {
              remoteAs = ciliumAsn;
              softReconfiguration = true;
              ebgpMultihop = 4;
              # updateSource = lib.mkIf hasMeshConfig "dummy0";
              listenRange = "${environment.kubernetes.clusterCidr}"; # "127.0.0.1/32";
            };

            neighbors = lib.optional (uplinkIp != null) {
              ip = uplinkIp;
              asn = 65000;
              routeMapIn = "FROM-UPLINK-IN";
            };

            addressFamilies.ipv4-unicast = {
              neighbors = lib.optionalAttrs (uplinkIp != null) {
                ${uplinkIp} = {
                  activate = true;
                  nextHopSelf = false;
                };
              };
              peerGroups.cilium = {
                activate = true;
                # nextHopSelf = true; # TODO: Verify...
              };
            };
          };
        };
      };
  };
}

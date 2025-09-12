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
      bgpHubHosts = lib.mapAttrsToList (hostname: hostConfig: hostConfig.ipv4) (
        lib.attrsets.filterAttrs (
          hostname: hostConfig:
          builtins.elem "bgp-hub" hostConfig.roles && hostConfig.environment == currentHostEnvironment
        ) config.flake.hosts
      );
    in
    if bgpHubHosts != [ ] then lib.head bgpHubHosts else null;
in
{
  flake.modules.nixos.cilium-bgp =
    {
      lib,
      environment,
      hostOptions,
      ...
    }:
    let
      # Get the thunderbolt mesh configuration if it exists
      hasMeshConfig = hostOptions.tags ? "thunderbolt-loopback-ipv4";

      # For nodes with thunderbolt mesh, get the loopback IP
      # For other nodes, use the main IP
      nodeLoopbackIp =
        if hasMeshConfig then hostOptions.tags."thunderbolt-loopback-ipv4" else hostOptions.ipv4;

      # Get local ASN from host tags or use default
      localAsn =
        if hostOptions.tags ? "bgp-asn" then
          lib.toInt hostOptions.tags."bgp-asn"
        else
          # Default logic for nodes without specific ASN
          65001;

      uplinkIp = findBgpHub hostOptions.environment;
    in
    {
      imports = [ ./_module/bgp.nix ];

      config = {
        services.bgp = {
          localAsn = localAsn;
          routerId = lib.mkIf (!hasMeshConfig) nodeLoopbackIp;

          prefixLists = {
            CILIUM-ROUTES = [
              "permit ${environment.kubernetes.clusterCidr} ge 16 le 32"
              "permit ${environment.kubernetes.serviceCidr} ge 16 le 32"
              "permit 10.0.0.0/8 le 32"
            ];
            DEFAULT-ONLY = [
              "permit 0.0.0.0/0"
            ];
          };

          routeMaps = [
            "route-map CILIUM-INGRESS-FIX permit 10"
            "  match ip address prefix-list CILIUM-ROUTES"
            "  set ip next-hop ${nodeLoopbackIp}"
            "route-map FROM-UPLINK-IN permit 10"
            "  match ip address prefix-list DEFAULT-ONLY"
          ];

          peerGroups.cilium = {
            remoteAs = localAsn;
            softReconfiguration = true;
            ebgpMultihop = 4;
            updateSource = lib.mkIf hasMeshConfig "dummy0";
            listenRange = "${nodeLoopbackIp}/32";
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
              nextHopSelf = true;
            };
          };
        };
      };
    };
}

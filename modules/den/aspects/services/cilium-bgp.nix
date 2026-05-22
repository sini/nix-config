{ den, lib, config, ... }:
let
  environments = config.den.environments or { };
  clusters = config.den.clusters or { };
in
{
  # Cilium BGP — FRR peering with cilium for pod/service/LB route advertisement
  den.aspects.services.cilium-bgp = {
    includes = [ den.aspects.services.bgp ];

    settings = {
      localAsn = lib.mkOption {
        type = lib.types.int;
        default = 65002;
        description = "Cilium BGP AS number for this node";
      };
    };

    nixos =
      { config, host, ... }:
      let
        inherit (lib)
          attrNames
          attrValues
          concatMap
          filterAttrs
          findFirst
          head
          optional
          optionalAttrs
          ;

        ciliumAsn = host.settings.services.cilium-bgp.localAsn;

        # Find the bgp-hub host in the same environment for uplink peering
        allHosts = config.den.hosts.x86_64-linux or { };
        hubHost =
          let
            candidates = filterAttrs (
              _name: h: h.environment == host.environment && h.name != host.name
            ) allHosts;
            hubName = findFirst (
              name: (candidates.${name}.settings.services.bgp or { }) ? hub
            ) null (attrNames candidates);
          in
          if hubName != null then candidates.${hubName} else null;

        uplinkIp = if hubHost != null then head hubHost.ipv4 else null;

        # Resolve cluster networks for this host's environment
        hostCluster =
          let
            matching = filterAttrs (_: c: c.environment == host.environment) clusters;
            names = attrNames matching;
          in
          if names != [ ] then matching.${head names} else null;

        podCidr =
          if hostCluster != null then
            hostCluster.networks.kubernetes-pods.cidr
          else
            "172.20.0.0/16";
        serviceCidr =
          if hostCluster != null then
            hostCluster.networks.kubernetes-services.cidr
          else
            "172.21.0.0/16";
        loadbalancerCidr =
          if hostCluster != null then
            hostCluster.networks.kubernetes-loadbalancers.cidr
          else
            "172.22.0.0/16";
      in
      {
        config.services.bgp = {
          prefixLists = {
            POD-ROUTES = [
              "permit ${podCidr} le 32"
            ];
            SERVICE-ROUTES = [
              "permit ${serviceCidr} le 32"
            ];
            LOADBALANCER-ROUTES = [
              "permit ${loadbalancerCidr} le 32"
            ];
            DEFAULT-ONLY = [
              "permit 0.0.0.0/0"
            ];
          };

          routeMaps = [
            # Only announce loadbalancer IPs to uplink (bgp-hub)
            # Pod and service IPs are only announced across the mesh
            "route-map TO-UPLINK-OUT permit 10"
            "  match ip address prefix-list LOADBALANCER-ROUTES"
            "route-map FROM-UPLINK-IN permit 10"
            "  match ip address prefix-list DEFAULT-ONLY"
          ];

          peerGroups.cilium = {
            remoteAs = ciliumAsn;
            softReconfiguration = true;
            listenRange = "${head host.ipv4}/32";
          };

          neighbors = optional (uplinkIp != null) {
            ip = uplinkIp;
            asn = 65000;
            routeMapIn = "FROM-UPLINK-IN";
            routeMapOut = "TO-UPLINK-OUT";
          };

          addressFamilies.ipv4-unicast = {
            neighbors = optionalAttrs (uplinkIp != null) {
              ${uplinkIp} = {
                activate = true;
                nextHopSelf = false;
              };
            };
            peerGroups.cilium = {
              activate = true;
            };
          };
        };
      };
  };
}

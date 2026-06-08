{
  den,
  lib,
  config,
  ...
}:
let
  clusters = config.den.clusters or { };
in
{
  # Cilium BGP — FRR peering with cilium for pod/service/LB route advertisement
  den.aspects.services.bgp.cilium-bgp = {
    includes = [ den.aspects.services.bgp ];

    settings = {
      localAsn = lib.mkOption {
        type = lib.types.int;
        default = 65002;
        description = "Cilium BGP AS number for this node";
      };
    };

    nixos =
      { host, bgp-peers, ... }:
      let
        inherit (lib)
          attrNames
          filterAttrs
          findFirst
          head
          optional
          optionalAttrs
          ;

        ciliumAsn = host.settings.services.bgp.cilium-bgp.localAsn;
        localAsn = host.settings.services.bgp.localAsn;

        # Find the BGP hub (uplink) from collected peers. In this hub/spoke
        # design spokes share one AS (65001) and the hub sits in a distinct AS
        # (65000), so the hub is the unique peer whose base ASN differs from
        # ours. Spokes peer north/south with the hub only; east/west
        # axon-to-axon routing is handled by OpenFabric.
        hubPeer = findFirst (p: p.asn != localAsn) null (lib.filter (p: p.hostname != host.name) bgp-peers);

        uplinkIp = if hubPeer != null then hubPeer.ip else null;

        # Resolve cluster networks for this host's environment
        hostCluster =
          let
            matching = filterAttrs (_: c: c.environment == host.environment) clusters;
            names = attrNames matching;
          in
          if names != [ ] then matching.${head names} else null;

        podCidr =
          if hostCluster != null then hostCluster.networks.kubernetes-pods.cidr else "172.20.0.0/16";
        serviceCidr =
          if hostCluster != null then hostCluster.networks.kubernetes-services.cidr else "172.21.0.0/16";
        loadbalancerCidr =
          if hostCluster != null then hostCluster.networks.kubernetes-loadbalancers.cidr else "172.22.0.0/16";
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
            inherit (hubPeer) asn;
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

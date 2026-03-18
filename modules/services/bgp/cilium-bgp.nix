# Cilium BGP configuration for Kubernetes clusters
# Handles BGP peering with Cilium for pod/service CIDR advertisement
{
  flake.features.cilium-bgp = {
    requires = [ "bgp-core" ];
    linux =
      {
        lib,
        environment,
        host,
        ...
      }:
      let
        nodeLoopbackIp = builtins.head host.ipv4;

        # Get local ASN from host tags or use default
        localAsn =
          if host.tags ? "bgp-asn" then
            lib.toInt host.tags."bgp-asn"
          else
            # Default logic for nodes without specific ASN
            65001;

        ciliumAsn =
          if host.tags ? "cilium-asn" then
            lib.toInt host.tags."cilium-asn"
          else
            # Default logic for nodes without specific ASN
            65002;

        uplinkIp =
          let
            bgpHubHosts = environment.findHostsByRole "bgp-hub" |> lib.attrValues;
          in
          if bgpHubHosts == [ ] then null else lib.head (lib.head bgpHubHosts).ipv4;

        # Access networks by name
        podNetwork = environment.networks.kubernetes-pods;
        serviceNetwork = environment.networks.kubernetes-services;
        loadbalancerNetwork = environment.networks.kubernetes-loadbalancers;
      in
      {
        config = {
          services.bgp = {
            inherit localAsn;
            routerId = nodeLoopbackIp;

            prefixLists = {
              POD-ROUTES = [
                "permit ${podNetwork.cidr} le 32"
              ];
              SERVICE-ROUTES = [
                "permit ${serviceNetwork.cidr} le 32"
              ];
              LOADBALANCER-ROUTES = [
                "permit ${loadbalancerNetwork.cidr} le 32"
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
              # ebgpMultihop = 4;
              # updateSource = lib.mkIf hasMeshConfig "dummy0";
              listenRange = "${builtins.head host.ipv4}/32"; # "${podNetwork.cidr}"; # "127.0.0.1/32";
            };

            neighbors = lib.optional (uplinkIp != null) {
              ip = uplinkIp;
              asn = 65000;
              routeMapIn = "FROM-UPLINK-IN";
              routeMapOut = "TO-UPLINK-OUT";
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

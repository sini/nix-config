# Cilium BGP peering policy for Kubernetes clusters.
{ den, lib, ... }:
{
  den.aspects.cilium-bgp = {

    settings = {
      localAsn = lib.mkOption {
        type = lib.types.int;
        default = 65002;
        description = "Cilium BGP AS number for this node";
      };
    };

    config = {
      includes = [ den.aspects.bgp ];

      nixos = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          lib,
          ...
        }:
        let
          ciliumAsn = host.settings.cilium-bgp.localAsn;

          uplinkIp =
            let
              bgpHubHosts = environment.findHostsByFeature "bgp-hub" |> lib.attrValues;
            in
            if bgpHubHosts == [ ] then null else lib.head (lib.head bgpHubHosts).ipv4;

          inherit (host) cluster;
          podNetwork = if cluster != null then cluster.networks.kubernetes-pods else { cidr = ""; };
          serviceNetwork = if cluster != null then cluster.networks.kubernetes-services else { cidr = ""; };
          loadbalancerNetwork =
            if cluster != null then cluster.networks.kubernetes-loadbalancers else { cidr = ""; };
        in
        lib.mkIf (cluster != null) {
          services.bgp = {
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
              "route-map TO-UPLINK-OUT permit 10"
              "  match ip address prefix-list LOADBALANCER-ROUTES"
              "route-map FROM-UPLINK-IN permit 10"
              "  match ip address prefix-list DEFAULT-ONLY"
            ];

            peerGroups.cilium = {
              remoteAs = ciliumAsn;
              softReconfiguration = true;
              listenRange = "${builtins.head host.ipv4}/32";
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
              peerGroups.cilium.activate = true;
            };
          };
        }
      );
    };
  };
}

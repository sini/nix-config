# Cilium BGP configuration for Kubernetes clusters
# Handles BGP peering with Cilium for pod/service CIDR advertisement
{ lib, ... }:
{
  features.cilium-bgp = {
    requires = [ "bgp" ];

    settings = {
      localAsn = lib.mkOption {
        type = lib.types.int;
        default = 65002;
        description = "Cilium BGP AS number for this node";
      };
    };

    linux =
      {
        lib,
        cluster,
        environment,
        host,
        settings,
        ...
      }:
      let
        ciliumAsn = settings.cilium-bgp.localAsn;

        uplinkIp =
          let
            bgpHubHosts = environment.findHostsByFeature "bgp-hub" |> lib.attrValues;
          in
          if bgpHubHosts == [ ] then null else lib.head (lib.head bgpHubHosts).ipv4;

        # Access cluster networks by name
        podNetwork = cluster.networks.kubernetes-pods;
        serviceNetwork = cluster.networks.kubernetes-services;
        loadbalancerNetwork = cluster.networks.kubernetes-loadbalancers;
      in
      {
        config = {
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

# Cilium BGP peering policy for Kubernetes clusters.
#
# Handles BGP peering with Cilium for pod/service CIDR advertisement.
#
# NOTE: Settings that should be typed (not yet in schema):
#   - cilium-bgp.localAsn (int, default 65002)
{ den, ... }:
{
  den.aspects.cilium-bgp = den.lib.perHost (
    { host }:
    let
      inherit (host) environment;
    in
    {
      nixos =
        {
          lib,
          ...
        }:
        let
          # TODO: Wire to den settings when schema is ready
          ciliumAsn = 65002;

          uplinkIp =
            let
              bgpHubHosts = environment.findHostsByFeature "bgp-hub" |> lib.attrValues;
            in
            if bgpHubHosts == [ ] then null else lib.head (lib.head bgpHubHosts).ipv4;

          # Access cluster networks by name
          cluster = host.cluster or null;
          podNetwork = if cluster != null then cluster.networks.kubernetes-pods else null;
          serviceNetwork = if cluster != null then cluster.networks.kubernetes-services else null;
          loadbalancerNetwork = if cluster != null then cluster.networks.kubernetes-loadbalancers else null;
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
              # Only announce loadbalancer IPs to uplink (bgp-hub)
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
              peerGroups.cilium = {
                activate = true;
              };
            };
          };
        };
    }
  );
}

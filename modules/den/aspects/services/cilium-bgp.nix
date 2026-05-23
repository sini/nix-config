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

        ciliumAsn = host.settings.services.cilium-bgp.localAsn;

        # Find the BGP hub from collected peers — hub is identified by
        # having a hub settings block in the bgp aspect
        hubPeer =
          let
            candidates = lib.filter (p: p.environment == host.environment && p.hostname != host.name) bgp-peers;
          in
          # The hub is the peer that isn't this host in the same environment.
          # bgp-peers only contains hosts running the bgp aspect, so the hub
          # is the one with the distinct ASN (hub uses 65001, spokes use 65002+).
          # Since we can't inspect settings from pipe data alone, we rely on
          # the hub being the only non-self peer with a different ASN.
          findFirst (p: p.asn != ciliumAsn) null candidates;

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

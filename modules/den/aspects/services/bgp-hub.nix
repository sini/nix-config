# BGP hub configuration — extends the bgp base aspect.
#
# Auto-discovers neighbors from hosts with the bgp-spoke feature and
# optionally peers with the environment gateway.
#
# NOTE: Settings that should be typed (not yet in schema):
#   - bgp-hub.neighbors (list of { address, asNumber, defaultOriginate })
#   - bgp-hub.autoDiscoverNeighbors (bool)
#   - bgp-hub.neighborDiscoveryRole (str)
#   - bgp-hub.neighborAsNumberBase (int)
#   - bgp-hub.defaultOriginateToNeighbors (bool)
#   - bgp-hub.maximumPaths (int)
#   - bgp-hub.peerWithGateway (bool)
#   - bgp-hub.gatewayAsNumber (int)
{ den, ... }:
{
  den.aspects.bgp-hub = den.lib.perHost (
    { host }:
    let
      inherit (host) environment;
    in
    {
      nixos =
        {
          config,
          lib,
          ...
        }:
        let
          # TODO: Wire these to den settings once schema is ready
          cfg = {
            neighbors = [ ];
            autoDiscoverNeighbors = false;
            neighborDiscoveryRole = "bgp-spoke";
            neighborAsNumberBase = 65001;
            defaultOriginateToNeighbors = true;
            maximumPaths = 8;
            peerWithGateway = true;
            gatewayAsNumber = 65999;
          };

          currentHostEnvironment = host.environment;

          getHostsByFeature =
            feature:
            lib.filterAttrs (
              _name: h: h.hasFeature feature && h.environment == currentHostEnvironment
            ) config.den.hosts;

          # Gateway neighbor (Unifi router)
          gatewayNeighbor =
            if cfg.peerWithGateway then
              [
                {
                  ip = environment.networks.default.gatewayIp;
                  asn = cfg.gatewayAsNumber;
                }
              ]
            else
              [ ];

          # Auto-generate neighbors from hosts with the configured feature
          shouldAutoDiscover = cfg.autoDiscoverNeighbors || (cfg.neighbors == [ ]);
          autoNeighbors =
            if shouldAutoDiscover then
              let
                targetHosts = getHostsByFeature cfg.neighborDiscoveryRole;
                sortedHostnames = lib.sort (a: b: a < b) (lib.attrNames targetHosts);
                sortedNeighbors = lib.imap0 (index: hostname: {
                  ip = builtins.head targetHosts.${hostname}.ipv4;
                  asn = targetHosts.${hostname}.settings.bgp.localAsn or (cfg.neighborAsNumberBase + index);
                }) sortedHostnames;
              in
              sortedNeighbors
            else
              [ ];

          # Convert manual neighbors to BGP module format
          manualNeighbors = map (neighbor: {
            ip = neighbor.address;
            asn = neighbor.asNumber;
          }) cfg.neighbors;

          # Combine gateway, manual, and auto-discovered neighbors
          allNeighbors = gatewayNeighbor ++ manualNeighbors ++ autoNeighbors;

          # Create address family configuration for all neighbors
          addressFamilyNeighbors = lib.listToAttrs (
            map (
              neighbor:
              let
                isGateway = neighbor.ip == environment.networks.default.gatewayIp;

                shouldOriginate =
                  if isGateway then
                    false
                  else if cfg.neighbors != [ ] then
                    let
                      matchingManual = lib.findFirst (n: n.address == neighbor.ip) null cfg.neighbors;
                    in
                    if matchingManual != null then matchingManual.defaultOriginate else cfg.defaultOriginateToNeighbors
                  else
                    cfg.defaultOriginateToNeighbors;
              in
              {
                name = neighbor.ip;
                value = {
                  activate = true;
                  nextHopSelf = false;
                  defaultOriginate = shouldOriginate;
                };
              }
            ) allNeighbors
          );
        in
        {
          boot.kernel.sysctl = {
            "net.ipv4.ip_forward" = lib.mkDefault 1;
            "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
          };

          services.bgp = {
            inherit (cfg) maximumPaths;

            neighbors = allNeighbors;

            addressFamilies.ipv4-unicast = {
              neighbors = addressFamilyNeighbors;
            };
          };
        };
    }
  );
}

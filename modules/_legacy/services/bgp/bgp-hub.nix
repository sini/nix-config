{
  config,
  lib,
  ...
}:
let
  getHostsByFeature =
    feature: currentHostEnvironment:
    lib.filterAttrs (
      _name: host: host.hasFeature feature && host.environment == currentHostEnvironment
    ) config.hosts;

  neighborType = lib.types.submodule {
    options = {
      address = lib.mkOption {
        type = lib.types.str;
        description = "Neighbor IP address";
      };
      asNumber = lib.mkOption {
        type = lib.types.int;
        description = "Neighbor AS number";
      };
      defaultOriginate = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to originate default route to this neighbor";
      };
    };
  };
in
{
  features.bgp-hub = {
    requires = [ "bgp" ];

    settings = {
      neighbors = lib.mkOption {
        type = lib.types.listOf neighborType;
        default = [ ];
        description = "List of manually configured BGP neighbors";
      };
      autoDiscoverNeighbors = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically discover neighbors from flake hosts";
      };
      neighborDiscoveryRole = lib.mkOption {
        type = lib.types.str;
        default = "bgp-spoke";
        description = "Feature name to filter hosts for auto-discovery";
      };
      neighborAsNumberBase = lib.mkOption {
        type = lib.types.int;
        default = 65001;
        description = "Base AS number for auto-discovered neighbors (fallback when host has no bgp.localAsn setting)";
      };
      defaultOriginateToNeighbors = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to originate default route to auto-discovered neighbors";
      };
      maximumPaths = lib.mkOption {
        type = lib.types.int;
        default = 8;
        description = "Maximum number of BGP paths";
      };
      peerWithGateway = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to automatically peer with the environment gateway (Unifi router)";
      };
      gatewayAsNumber = lib.mkOption {
        type = lib.types.int;
        default = 65999;
        description = "AS number of the gateway router";
      };
    };

    linux =
      {
        lib,
        host,
        environment,
        settings,
        ...
      }:
      let
        cfg = settings.bgp-hub;
        currentHostEnvironment = host.environment;

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
              targetHosts = getHostsByFeature cfg.neighborDiscoveryRole currentHostEnvironment;

              # Get sorted hostnames for consistent AS number assignment
              sortedHostnames = lib.sort (a: b: a < b) (lib.attrNames targetHosts);

              # Create neighbors using their bgp localAsn setting or fallback to index-based AS numbers
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
              # Never send default-originate to the gateway (it's our internet source)
              isGateway = neighbor.ip == environment.networks.default.gatewayIp;

              shouldOriginate =
                if isGateway then
                  false
                else if cfg.neighbors != [ ] then
                  # For manual neighbors, check their defaultOriginate setting
                  let
                    matchingManual = lib.findFirst (n: n.address == neighbor.ip) null cfg.neighbors;
                  in
                  if matchingManual != null then matchingManual.defaultOriginate else cfg.defaultOriginateToNeighbors
                else
                  # For auto-discovered neighbors, use the global setting
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
        config = lib.mkIf (host.hasFeature "bgp-hub") {
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
      };
  };
}

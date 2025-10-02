{
  config,
  lib,
  ...
}:
let
  # Helper to get hosts with a specific tag or role in the same environment
  getHostsByTag =
    tag: value: currentHostEnvironment:
    lib.filterAttrs (
      name: host:
      (host.tags or { }) ? ${tag}
      && host.tags.${tag} == value
      && host.environment == currentHostEnvironment
    ) config.flake.hosts;

  getHostsByRole =
    role: currentHostEnvironment:
    lib.filterAttrs (
      name: host: lib.elem role (host.roles or [ ]) && host.environment == currentHostEnvironment
    ) config.flake.hosts;
in
{
  flake.features.bgp-hub = {
    requires = [ "bgp-core" ];
    nixos =
      {
        config,
        lib,
        hostOptions,
        ...
      }:
      let
        cfg = config.services.bgp-hub;
        currentHostEnvironment = hostOptions.environment;

        # Auto-generate neighbors from hosts with specific tags/roles
        shouldAutoDiscover = cfg.autoDiscoverNeighbors || (cfg.neighbors == [ ]);
        autoNeighbors =
          if shouldAutoDiscover then
            let
              # Find hosts matching the target pattern
              targetHosts =
                if cfg.neighborSelector.tag != null then
                  getHostsByTag cfg.neighborSelector.tag cfg.neighborSelector.value currentHostEnvironment
                else if cfg.neighborSelector.role != null then
                  getHostsByRole cfg.neighborSelector.role currentHostEnvironment
                else
                  { };

              # Get sorted hostnames for consistent AS number assignment
              sortedHostnames = lib.sort (a: b: a < b) (lib.attrNames targetHosts);

              # Create neighbors using their bgp-asn tags or fallback to index-based AS numbers
              sortedNeighbors = lib.imap0 (index: hostname: {
                ip = builtins.head targetHosts.${hostname}.ipv4;
                asn =
                  if (targetHosts.${hostname}.tags or { }) ? "bgp-asn" then
                    lib.toInt targetHosts.${hostname}.tags."bgp-asn"
                  else
                    cfg.neighborAsNumberBase + index;
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

        # Combine manual and auto-discovered neighbors
        allNeighbors = manualNeighbors ++ autoNeighbors;

        # Create address family configuration for all neighbors
        addressFamilyNeighbors = lib.listToAttrs (
          map (
            neighbor:
            let
              shouldOriginate =
                if cfg.neighbors != [ ] then
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

        localAsn =
          if hostOptions.tags ? "bgp-asn" then lib.toInt hostOptions.tags."bgp-asn" else cfg.localAsNumber;
      in
      {
        options.services.bgp-hub = {
          localAsNumber = lib.mkOption {
            type = lib.types.int;
            default = 65000;
            description = "Local BGP AS number (fallback if no bgp-asn tag)";
          };

          neighbors = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
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
              }
            );
            default = [ ];
            description = "List of manually configured BGP neighbors";
          };

          autoDiscoverNeighbors = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Automatically discover neighbors from flake hosts";
          };

          neighborSelector = lib.mkOption {
            type = lib.types.submodule {
              options = {
                tag = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Tag name to filter hosts";
                };
                value = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Tag value to match";
                };
                role = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = "bgp-spoke";
                  description = "Role to filter hosts";
                };
              };
            };
            default = { };
            description = "Selector for auto-discovering neighbors";
          };

          neighborAsNumberBase = lib.mkOption {
            type = lib.types.int;
            default = 65001;
            description = "Base AS number for auto-discovered neighbors";
          };

          neighborAsNumberOffset = lib.mkOption {
            type = lib.types.functionTo lib.types.int;
            default = hostname: 0;
            description = "Function to calculate AS number offset from hostname based on sorted position";
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
        };

        config = lib.mkIf (builtins.elem "bgp-hub" (hostOptions.roles or [ ])) {
          boot.kernel.sysctl = {
            "net.ipv4.ip_forward" = lib.mkDefault 1;
            "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
          };

          services.bgp = {
            localAsn = localAsn;
            routerId = builtins.head hostOptions.ipv4;
            maximumPaths = cfg.maximumPaths;

            neighbors = allNeighbors;

            addressFamilies.ipv4-unicast = {
              neighbors = addressFamilyNeighbors;
            };
          };
        };
      };
  };
}

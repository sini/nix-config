{
  config,
  lib,
  ...
}:
let
  generateNeighborConfig = neighbor: ''
    neighbor ${neighbor.address} remote-as ${toString neighbor.asNumber}
  '';

  generateAddressFamilyConfig = neighbor: ''
    neighbor ${neighbor.address} activate
    ${lib.optionalString (neighbor.defaultOriginate or false
    ) "neighbor ${neighbor.address} default-originate"}
  '';

  # Helper to get hosts with a specific tag or role
  getHostsByTag =
    tag: value:
    lib.filterAttrs (
      name: host: (host.tags or { }) ? ${tag} && host.tags.${tag} == value
    ) config.flake.hosts;

  getHostsByRole =
    role: lib.filterAttrs (name: host: lib.elem role (host.roles or [ ])) config.flake.hosts;
in
{
  flake.modules.nixos.bgp-uplink =
    {
      config,
      lib,
      hostOptions,
      ...
    }:
    let
      cfg = config.services.bgp-uplink;

      # Auto-generate neighbors from hosts with specific tags/roles
      autoNeighbors =
        if cfg.autoDiscoverNeighbors then
          let
            # Find hosts matching the target pattern
            targetHosts =
              if cfg.neighborSelector.tag != null then
                getHostsByTag cfg.neighborSelector.tag cfg.neighborSelector.value
              else if cfg.neighborSelector.role != null then
                getHostsByRole cfg.neighborSelector.role
              else
                { };

            # Convert to neighbor entries
            hostNeighbors = lib.mapAttrsToList (name: host: {
              address = host.ipv4;
              asNumber = cfg.neighborAsNumberBase + (cfg.neighborAsNumberOffset name);
              defaultOriginate = cfg.defaultOriginateToNeighbors;
            }) targetHosts;
          in
          hostNeighbors
        else
          [ ];

      # Combine manual and auto-discovered neighbors
      allNeighbors = cfg.neighbors ++ autoNeighbors;
    in
    {
      options.services.bgp-uplink = {
        enable = lib.mkEnableOption "BGP uplink configuration";

        localAsNumber = lib.mkOption {
          type = lib.types.int;
          default = 65000;
          description = "Local BGP AS number";
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
                default = null;
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
          default =
            hostname:
            let
              # Extract number from hostname if it ends with digits
              match = builtins.match ".*-([0-9]+)" hostname;
              num = if match != null then lib.toInt (builtins.head match) else 0;
            in
            num - 1;
          description = "Function to calculate AS number offset from hostname";
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

      config = lib.mkIf cfg.enable {
        boot = {
          kernel.sysctl = {
            "net.ipv4.ip_forward" = lib.mkDefault 1;
            "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
          };
        };

        services.frr = {
          bgpd.enable = true;
          config = ''
            ip forwarding
            !
            router bgp ${toString cfg.localAsNumber}
              bgp router-id ${hostOptions.ipv4}
              no bgp ebgp-requires-policy
              bgp bestpath as-path multipath-relax
              maximum-paths ${toString cfg.maximumPaths}
              !
              ${lib.concatMapStringsSep "\n  " generateNeighborConfig allNeighbors}
              !
              address-family ipv4 unicast
                ${lib.concatMapStringsSep "\n    " generateAddressFamilyConfig allNeighbors}
              exit-address-family
          '';
        };
      };
    };
}

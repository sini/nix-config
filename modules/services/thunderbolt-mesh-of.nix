# Thunderbolt mesh networking with OpenFabric (IS-IS).
#
# Uses FRR's fabricd for automatic adjacency discovery and route distribution
# across thunderbolt links. Adjacencies form automatically — no IP assignment
# or manual peer config needed on the point-to-point interfaces.
#
# Coexists with BGP (cilium-bgp, bgp-hub) in the same FRR instance.
# OpenFabric handles east/west (host↔host), BGP handles north/south.
#
# Host config:
#   feature-settings.thunderbolt-mesh-of = {
#     interfaces = [ "enp199s0f5" "enp199s0f6" ];
#     loopback.ipv4 = "172.16.255.1/32";
#     nsap = "49.0000.0000.0001.00";
#   };
{ lib, ... }:
{
  features.thunderbolt-mesh-of = {
    settings = {
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Thunderbolt interface names to enable OpenFabric on";
        example = [
          "enp199s0f5"
          "enp199s0f6"
        ];
      };
      loopback = lib.mkOption {
        type = lib.types.submodule {
          options = {
            ipv4 = lib.mkOption {
              type = lib.types.str;
              description = "IPv4 loopback address in CIDR (e.g., '172.16.255.1/32')";
            };
            ipv6 = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "IPv6 loopback address in CIDR (e.g., 'fdb4:5edb:1b00::1/128')";
            };
          };
        };
        description = "Loopback addresses for this node in the OpenFabric fabric";
      };
      nsap = lib.mkOption {
        type = lib.types.str;
        description = "ISO NSAP address for this node (e.g., '49.0000.0000.0001.00')";
      };
    };

    linux =
      { lib, settings, ... }:
      let
        cfg = settings.thunderbolt-mesh-of;

        fabricInterfaceConfig = lib.concatMapStringsSep "\n" (ifName: ''
          !
          interface ${ifName}
            ip router openfabric 1
            ${lib.optionalString (cfg.loopback.ipv6 != null) "ipv6 router openfabric 1"}
            openfabric csnp-interval 2
            openfabric hello-interval 1
            openfabric hello-multiplier 2
        '') cfg.interfaces;
      in
      {
        config = {
          boot = {
            kernelParams = [ "pcie=pcie_bus_perf" ];
            kernelModules = [
              "thunderbolt"
              "thunderbolt-net"
            ];
          };

          # Loopback address for fabric routing
          networking.interfaces.lo.ipv4.addresses = [
            {
              address = lib.head (lib.splitString "/" cfg.loopback.ipv4);
              prefixLength = lib.toInt (lib.last (lib.splitString "/" cfg.loopback.ipv4));
            }
          ];

          systemd = {
            services.frr = {
              requires = map (i: "sys-subsystem-net-devices-${i}.device") cfg.interfaces;
              after = map (i: "sys-subsystem-net-devices-${i}.device") cfg.interfaces;
            };

            # Match all thunderbolt interfaces by driver — no per-device network config needed
            network = {
              networks."20-thunderbolt" = {
                matchConfig.Driver = "thunderbolt-net";
                linkConfig = {
                  ActivationPolicy = "up";
                  MTUBytes = "1500";
                };
                networkConfig.LinkLocalAddressing = "no";
              };

              config.networkConfig = {
                IPv4Forwarding = true;
                IPv6Forwarding = true;
              };
            };
          };

          services.frr = {
            fabricd.enable = true;

            config = lib.mkAfter ''
              ! OpenFabric thunderbolt mesh
              ${fabricInterfaceConfig}
              !
              interface lo
                ip router openfabric 1
                ${lib.optionalString (cfg.loopback.ipv6 != null) "ipv6 router openfabric 1"}
                openfabric passive
              !
              router openfabric 1
                net ${cfg.nsap}
                fabric-tier 0
            '';
          };
        };
      };
  };
}

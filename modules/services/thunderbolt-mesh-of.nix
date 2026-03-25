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
#   settings.thunderbolt-mesh-of = {
#     interfaces = [ "enp199s0f5" "enp199s0f6" ];
#     loopback.ipv4 = "172.16.255.1/32";
#     nsap = "49.0000.0000.0001.00";
#   };
{ lib, ... }:
{
  features.thunderbolt-mesh-of = {
    requires = [ "thunderbolt-network" ];

    settings = {
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Thunderbolt interface names to enable OpenFabric on (tb0, tb1, ... from thunderbolt hardware feature)";
        example = [
          "tb0"
          "tb1"
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
      {
        config,
        lib,
        environment,
        settings,
        ...
      }:
      let
        cfg = settings.thunderbolt-mesh-of;

        # Discover peers in the same environment for management IP routing
        peers = lib.filterAttrs (name: _: name != config.networking.hostName) (
          environment.findHostsByFeature "thunderbolt-mesh-of"
        );

        # Static routes: reach peer management IPs via their fabric loopback
        # OpenFabric resolves the loopback next-hop to the correct thunderbolt link
        peerStaticRoutes = lib.concatMapStringsSep "\n" (
          peerHost:
          let
            mgmtIp = builtins.head peerHost.ipv4;
            loopbackIp = lib.head (lib.splitString "/" peerHost.settings.thunderbolt-mesh-of.loopback.ipv4);
          in
          "ip route ${mgmtIp}/32 ${loopbackIp}"
        ) (lib.attrValues peers);

        mkFabricInterface =
          ifName:
          lib.concatStringsSep "\n" (
            [
              "interface ${ifName}"
              "  ip router openfabric 1"
            ]
            ++ lib.optional (cfg.loopback.ipv6 != null) "  ipv6 router openfabric 1"
            ++ [
              "  openfabric csnp-interval 2"
              "  openfabric hello-interval 1"
              "  openfabric hello-multiplier 2"
            ]
          );

        fabricInterfaceConfig = lib.concatMapStringsSep "\n!\n" mkFabricInterface cfg.interfaces;
      in
      {
        config = {
          # Loopback address for fabric routing
          networking.interfaces.lo.ipv4.addresses = [
            {
              address = lib.head (lib.splitString "/" cfg.loopback.ipv4);
              prefixLength = lib.toInt (lib.last (lib.splitString "/" cfg.loopback.ipv4));
            }
          ];

          systemd = {
            # FRR does not hard-depend on thunderbolt interfaces — OpenFabric
            # forms adjacencies dynamically when interfaces appear.

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

            config =
              let
                loopbackConfig = lib.concatStringsSep "\n" (
                  [
                    "interface lo"
                    "  ip router openfabric 1"
                  ]
                  ++ lib.optional (cfg.loopback.ipv6 != null) "  ipv6 router openfabric 1"
                  ++ [ "  openfabric passive" ]
                );
              in
              lib.mkAfter ''
                ! Route peer management IPs via fabric loopbacks
                ${peerStaticRoutes}
                !
                ! OpenFabric thunderbolt mesh
                ${fabricInterfaceConfig}
                !
                ${loopbackConfig}
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

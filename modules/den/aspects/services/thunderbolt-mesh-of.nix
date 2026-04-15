# Thunderbolt mesh networking with OpenFabric (IS-IS).
#
# Uses FRR's fabricd for automatic adjacency discovery and route distribution
# across thunderbolt links. Adjacencies form automatically.
#
# Coexists with BGP (cilium-bgp, bgp-hub) in the same FRR instance.
# OpenFabric handles east/west (host<->host), BGP handles north/south.
#
# NOTE: Settings that should be typed (not yet in schema):
#   - thunderbolt-mesh-of.interfaces (list of str)
#   - thunderbolt-mesh-of.loopback.ipv4 (str, CIDR)
#   - thunderbolt-mesh-of.loopback.ipv6 (nullOr str, CIDR)
#   - thunderbolt-mesh-of.nsap (str, ISO NSAP)
{ den, lib, ... }:
{
  den.aspects.thunderbolt-mesh-of = {
    settings = {
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Thunderbolt network interfaces for OpenFabric mesh";
      };
      loopback = {
        ipv4 = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Loopback IPv4 address with prefix (e.g., 172.16.255.1/32)";
        };
        ipv6 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Loopback IPv6 address with prefix (optional)";
        };
      };
      nsap = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "IS-IS NSAP address (e.g., 49.0000.0000.0001.00)";
      };
    };
    config = den.lib.perHost (
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
            # TODO: Wire to den settings when schema is ready
            cfg =
              host.settings.thunderbolt-mesh-of or {
                interfaces = [ ];
                loopback = {
                  ipv4 = "0.0.0.0/32";
                  ipv6 = null;
                };
                nsap = "49.0000.0000.0001.00";
              };

            # Discover peers in the same environment for management IP routing
            peers = lib.filterAttrs (name: _: name != config.networking.hostName) (
              environment.findHostsByFeature "thunderbolt-mesh-of"
            );

            # Static routes: reach peer management IPs via their fabric loopback
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
            # Loopback address for fabric routing
            networking.interfaces.lo.ipv4.addresses = [
              {
                address = lib.head (lib.splitString "/" cfg.loopback.ipv4);
                prefixLength = lib.toInt (lib.last (lib.splitString "/" cfg.loopback.ipv4));
              }
            ];

            systemd = {
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
      }
    );
  };
}

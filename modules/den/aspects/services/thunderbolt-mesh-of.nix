# Thunderbolt mesh networking with OpenFabric (IS-IS).
#
# Uses FRR's fabricd for automatic adjacency discovery and route distribution
# across thunderbolt links. Coexists with BGP in the same FRR instance —
# OpenFabric handles east/west (host-to-host), BGP handles north/south.
{
  den,
  lib,
  config,
  ...
}:
let
  allHosts = config.den.hosts.x86_64-linux or { };
in
{
  den.aspects.services.thunderbolt-mesh-of = {
    includes = [ den.aspects.hardware.thunderbolt-network ];

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
              description = "IPv6 loopback address in CIDR";
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

    nixos =
      {
        config,
        lib,
        host,
        ...
      }:
      let
        inherit (lib)
          attrValues
          concatMapStringsSep
          concatStringsSep
          filterAttrs
          head
          optional
          splitString
          ;

        cfg = (
          host.settings.services.thunderbolt-mesh-of or {
            interfaces = [ ];
            loopback.ipv4 = "0.0.0.0/32";
            nsap = "";
          }
        );
        environments = config.den.environments or { };

        # Check for actual mesh configuration, not just default option values
        hasMeshSettings =
          h:
          let
            meshCfg = (h.settings.services or { }).thunderbolt-mesh-of or { };
          in
          (meshCfg.loopback or { }) ? ipv4;

        # Discover peers: same environment, configured for thunderbolt mesh, not self
        peers = filterAttrs (
          name: h: h.environment == host.environment && name != host.name && hasMeshSettings h
        ) allHosts;

        # Static routes: reach peer management IPs via their fabric loopback
        peerStaticRoutes = concatMapStringsSep "\n" (
          peerHost:
          let
            peerCfg = peerHost.settings.services.thunderbolt-mesh-of;
            mgmtIp = head peerHost.ipv4;
            loopbackIp = head (splitString "/" peerCfg.loopback.ipv4);
          in
          "ip route ${mgmtIp}/32 ${loopbackIp}"
        ) (attrValues peers);

        mkFabricInterface =
          ifName:
          concatStringsSep "\n" (
            [
              "interface ${ifName}"
              "  ip router openfabric 1"
            ]
            ++ optional (cfg.loopback.ipv6 or null != null) "  ipv6 router openfabric 1"
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
          networking.interfaces.lo.ipv4.addresses = [
            {
              address = head (splitString "/" cfg.loopback.ipv4);
              prefixLength = lib.toInt (lib.last (splitString "/" cfg.loopback.ipv4));
            }
          ];

          systemd.network = {
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

          services.frr = {
            fabricd.enable = true;

            config =
              let
                loopbackConfig = concatStringsSep "\n" (
                  [
                    "interface lo"
                    "  ip router openfabric 1"
                  ]
                  ++ optional (cfg.loopback.ipv6 or null != null) "  ipv6 router openfabric 1"
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

# Thunderbolt mesh networking with OpenFabric (IS-IS).
#
# Uses FRR's fabricd for automatic adjacency discovery and route distribution
# across thunderbolt links. Coexists with BGP in the same FRR instance —
# OpenFabric handles east/west (host-to-host), BGP handles north/south.
#
# Emits thunderbolt-mesh-peers quirk; consumes collected peers for
# static route generation to reach management IPs via fabric loopbacks.
{
  den,
  lib,
  ...
}:
{
  den.aspects.services.networking.thunderbolt-mesh-of = {
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

    # Emit peer info for cross-host static route generation
    thunderbolt-mesh-peers =
      { host, ... }:
      let
        cfg = host.settings.services.networking.thunderbolt-mesh-of;
      in
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        loopbackIpv4 = cfg.loopback.ipv4;
        inherit (cfg) nsap;
      };

    nixos =
      {
        thunderbolt-mesh-peers,
        lib,
        host,
        ...
      }:
      let
        inherit (lib)
          concatMapStringsSep
          concatStringsSep
          head
          optional
          splitString
          ;

        cfg =
          host.settings.services.networking.thunderbolt-mesh-of or {
            interfaces = [ ];
            loopback.ipv4 = "0.0.0.0/32";
            nsap = "";
          };

        # Collected peers, not self (same-environment scoping guaranteed by
        # collect-thunderbolt-mesh-peers policy)
        peers = lib.filter (p: p.hostname != host.name) thunderbolt-mesh-peers;

        # Static routes: reach peer management IPs via their fabric loopback
        peerStaticRoutes = concatMapStringsSep "\n" (
          peer:
          let
            loopbackIp = head (splitString "/" peer.loopbackIpv4);
          in
          "ip route ${peer.ip}/32 ${loopbackIp}"
        ) peers;

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

        loopbackIp = head (splitString "/" cfg.loopback.ipv4);
        loopback6 = cfg.loopback.ipv6 or null;
        loopback6Ip = if loopback6 != null then head (splitString "/" loopback6) else null;
        fabricIfSet = concatStringsSep ", " (map (i: "\"${i}\"") cfg.interfaces);
        snatExcludeSet = concatStringsSep ", " (lib.unique ([ loopbackIp ] ++ host.ipv4));
        snat6ExcludeSet = concatStringsSep ", " (lib.unique ([ loopback6Ip ] ++ host.ipv6));
      in
      {
        config = {
          networking.interfaces.lo.ipv4.addresses = [
            {
              address = loopbackIp;
              prefixLength = lib.toInt (lib.last (splitString "/" cfg.loopback.ipv4));
            }
          ];

          networking.interfaces.lo.ipv6.addresses = lib.mkIf (loopback6 != null) [
            {
              address = loopback6Ip;
              prefixLength = lib.toInt (lib.last (splitString "/" loopback6));
            }
          ];

          # The fabric interfaces are unnumbered (loopback-based OpenFabric), so
          # nothing on the egress path can masquerade forwarded traffic — a
          # packet leaving the fabric with a non-host source (pod CIDRs, future
          # VM guests) reaches the peer with a source it rejects: Cilium
          # spoof-drops raw pod-IP packets arriving outside its tunnel.
          # Invariant: the fabric only carries host-addressed sources. Anything
          # else is SNAT'd to this node's fabric loopback; conntrack reverses
          # replies. Host-sourced traffic (loopback or mgmt IPs) passes
          # untouched. The ip6 table mirrors it when a v6 loopback is set
          # (link-local sources are left alone — they never leave the link).
          networking.nftables = lib.mkIf (cfg.interfaces != [ ]) {
            enable = true;
            tables.fabric-source-snat = {
              family = "ip";
              content = ''
                chain postrouting {
                  type nat hook postrouting priority srcnat; policy accept;
                  oifname { ${fabricIfSet} } ip saddr != { ${snatExcludeSet} } snat ip to ${loopbackIp}
                }
              '';
            };
            tables.fabric-source-snat6 = lib.mkIf (loopback6 != null) {
              family = "ip6";
              content = ''
                chain postrouting {
                  type nat hook postrouting priority srcnat; policy accept;
                  oifname { ${fabricIfSet} } ip6 saddr != { ${snat6ExcludeSet}, fe80::/10 } snat ip6 to ${loopback6Ip}
                }
              '';
            };
          };

          systemd.network = {
            networks."20-thunderbolt" = {
              matchConfig.Driver = "thunderbolt-net";
              linkConfig = {
                ActivationPolicy = "up";
                MTUBytes = "1500";
              };
              # v6 OpenFabric needs link-local on the fabric interfaces (IS-IS
              # v6 nexthops are link-local); without a v6 loopback, no v6 at all.
              networkConfig.LinkLocalAddressing = if loopback6 != null then "ipv6" else "no";
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

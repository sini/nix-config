# Networking Configuration Module
#
# This module manages network interfaces using systemd-networkd with support for
# both automatic and manual bridge configurations.
#
# ## Usage Examples
#
# ### Default (autobridging enabled):
# ```nix
# hardware.networking.interfaces = [ "enp1s0" "enp2s0" ];
# # Creates: br0 bridging enp1s0, br1 bridging enp2s0
# ```
#
# ### Manual bridges with multiple interfaces:
# ```nix
# hardware.networking = {
#   autobridging = false;
#   interfaces = [ "enp4s0" ];  # Optional: standalone interfaces only
#   bridges = {
#     "br0" = [ "enp1s0" "enp2s0" ];  # Multiple interfaces in one bridge
#     "br1" = [ "enp3s0" ];            # Single interface bridge
#   };
#   # enp4s0 will be configured as standalone
# };
# ```
#
# ### Bridges only (no standalone interfaces):
# ```nix
# hardware.networking = {
#   autobridging = false;
#   bridges = {
#     "br0" = [ "enp1s0" "enp2s0" ];
#     "br1" = [ "enp3s0" ];
#   };
#   # No need to list interfaces - they're automatically detected from bridges
# };
# ```
#
# ## Key Features
# - Automatic 1:1 bridging per interface (default behavior)
# - Manual bridge definitions with multiple interfaces
# - Automatic interface detection from bridge definitions
# - IPv6 support with DHCPv6 and SLAAC
# - DNS over TLS and DNSSEC
# - TCP congestion window optimization
{
  flake.features.networking.nixos =
    {
      config,
      hostOptions,
      environment,
      lib,
      ...
    }:
    with lib;
    let
      cfg = config.hardware.networking;

      # Extract subnet mask from management network CIDR (e.g., "10.9.0.0/16" -> "/16")
      managementSubnet = "/${last (splitString "/" environment.networks.management.cidr)}";

      # Helper to create name-value pairs for listToAttrs
      mkNameValue = name: value: { inherit name value; };

      # Common route configuration for TCP optimization
      mkRoute =
        gateway: extra:
        {
          Gateway = gateway;
          InitialCongestionWindow = 50;
          InitialAdvertisedReceiveWindow = 50;
        }
        // extra;

      # Common network configuration (used for both bridges and standalone interfaces)
      mkNetworkConfig = ipv4: {
        networkConfig = {
          Address = [ "${ipv4}${managementSubnet}" ];
          DHCP = "yes"; # enable DHCPv6 only, so we can get a GUA.
          IPv6AcceptRA = true; # for Stateless IPv6 Autoconfiguraton (SLAAC)
          IPv6PrivacyExtensions = "yes";
          LinkLocalAddressing = "ipv6";
          DNS = environment.dnsServers;
          DNSOverTLS = true;
          DNSSEC = "allow-downgrade";
        };
        dhcpV6Config = {
          UseDelegatedPrefix = true; # Request a prefix for our LANs.
          PrefixDelegationHint = "::/64";
        };
        routes = [
          (mkRoute environment.gatewayIp { })
          (mkRoute environment.gatewayIpV6 {
            Destination = "::/0";
            GatewayOnLink = true; # it's a gateway on local link.
          })
        ];
        linkConfig.RequiredForOnline = "routable";
      };

      # The effective bridges configuration (either from user or auto-generated)
      effectiveBridges = cfg.bridges;

      # Convert bridge attrset to list with additional metadata
      bridgeConfig = imap0 (idx: brName: {
        name = brName;
        interfaces = effectiveBridges.${brName};
        ipv4 = elemAt hostOptions.ipv4 idx;
      }) (attrNames effectiveBridges);

      # List of all bridge names
      bridgeNames = map (br: br.name) bridgeConfig;

      # Set of all interfaces that are part of bridges
      bridgedInterfaces = unique (concatMap (br: br.interfaces) bridgeConfig);

      # All interfaces we know about (from cfg.interfaces and from bridges)
      allInterfaces = unique (cfg.interfaces ++ bridgedInterfaces);

      # Interfaces that should be configured as standalone (not bridged)
      standaloneInterfaces = subtractLists bridgedInterfaces allInterfaces;

      # Create netdev configurations for bridges
      bridgeNetdevs = listToAttrs (
        map (
          br:
          mkNameValue br.name {
            # https://wiki.archlinux.org/title/Systemd-networkd#Inherit_MAC_address_(optional)
            # Mac address should come from the bridged interface
            netdevConfig = {
              Name = br.name;
              Kind = "bridge";
              MACAddress = "none";
            };
          }
        ) bridgeConfig
      );

      bridgeLinks = listToAttrs (
        map (
          br:
          mkNameValue br.name {
            matchConfig.Name = br.name;
            linkConfig.MACAddressPolicy = "none";
          }
        ) bridgeConfig
      );

      # Network configurations for physical interfaces (bind to bridges)
      bridgedInterfaceNetworks = listToAttrs (
        concatMap (
          br:
          map (
            ifName:
            mkNameValue ifName {
              enable = true;
              # We attach microvm's to the primary bridge br0
              matchConfig.Name =
                if br.name == "br0" then
                  [
                    ifName
                    "vm-*"
                  ]
                else
                  ifName;
              networkConfig.Bridge = br.name;
              linkConfig.RequiredForOnline = "enslaved";
            }
          ) br.interfaces
        ) bridgeConfig
      );

      # Network configuration for standalone interfaces (not bridged)
      standaloneInterfaceNetworks = listToAttrs (
        imap0 (
          idx: ifName:
          mkNameValue ifName (
            {
              enable = true;
              matchConfig.Name = ifName;
            }
            // (mkNetworkConfig (elemAt hostOptions.ipv4 (length bridgeConfig + idx)))
          )
        ) standaloneInterfaces
      );

      # Network configurations for bridges (DHCP and IPv6)
      bridgeNetworks = listToAttrs (
        map (
          br:
          mkNameValue br.name (
            {
              enable = true;
              matchConfig.Name = br.name;
            }
            // (mkNetworkConfig br.ipv4)
          )
        ) bridgeConfig
      );
    in
    {
      options.hardware.networking = with types; {
        interfaces = mkOption {
          type = listOf str;
          default = [ "enp1s0" ];
          description = ''
            List of interfaces to configure using systemd-networkd.

            When autobridging is enabled, a bridge will be created for each interface (br0, br1, br2, etc.).

            When autobridging is disabled:
            - Interfaces listed in bridges are automatically included (no need to duplicate them here)
            - Interfaces listed here but not in bridges will be configured as standalone networks
            - You only need to list additional standalone interfaces that aren't part of any bridge
          '';
        };

        autobridging = mkEnableOption "automatic 1:1 bridge creation for each interface" // {
          default = true;
        };

        bridges = mkOption {
          type = attrsOf (listOf str);
          default = { };
          example = literalExpression ''
            {
              "br0" = [ "enp2s0" "enp3s0" ];
              "br1" = [ "enp4s0" ];
            }
          '';
          description = ''
            Attribute set mapping bridge names to lists of interfaces.

            When autobridging is enabled (default), auto-generated 1:1 mappings are created
            (br0 = [enp1s0], br1 = [enp2s0], etc.) but can be overridden by setting this option.

            When autobridging is disabled, you must set this option to define bridges manually
            with multiple interfaces per bridge.
          '';
        };

        enableNetworkManager = mkEnableOption "Enable NetworkManager for managing network interfaces";

        unmanagedInterfaces = mkOption {
          type = listOf str;
          default = allInterfaces ++ bridgeNames;
          defaultText = "all interfaces (including those in bridges) ++ bridge names";
          description = ''
            List of interfaces to mark as unmanaged by NetworkManager.
            Defaults to all interfaces (from both interfaces and bridges options) and bridge devices.
          '';
        };
      };

      config = {
        # Auto-populate bridges when autobridging is enabled
        hardware.networking.bridges = mkIf cfg.autobridging (
          mkDefault (
            listToAttrs (imap0 (idx: ifName: mkNameValue "br${toString idx}" [ ifName ]) cfg.interfaces)
          )
        );

        boot.kernelModules = [
          "tun" # TUN/TAP networking
          "bridge" # Network bridging
          "macvtap" # MacVTap networking
        ];

        networking = {
          hostName = hostOptions.hostname;
          domain = environment.domain;
          hostId = with builtins; substring 0 8 (hashString "md5" config.networking.hostName);

          useDHCP = false;
          dhcpcd.enable = false;

          firewall = {
            enable = true;
            allowPing = true;
            logRefusedConnections = false;
          };
        };

        systemd.services."systemd-networkd-persistent-storage".enable = false;

        systemd.network = {
          enable = true;
          wait-online.enable = false;
          netdevs = bridgeNetdevs;
          links = bridgeLinks;
          networks = bridgedInterfaceNetworks // standaloneInterfaceNetworks // bridgeNetworks;
        };
      };
    };
}

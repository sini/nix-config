# Networking Configuration Module
#
# This module manages network interfaces using systemd-networkd with support for
# both automatic and manual bridge configurations.
#
# ## Usage Examples
#
# ### Simple interface configuration:
# ```nix
# flake.hosts.hostname = {
#   networking = {
#     interfaces = {
#       enp1s0 = {
#         ipv4 = [ "10.10.10.1" ];
#         ipv6 = [ "fe80::1" ];
#       };
#       enp2s0 = {
#         ipv4 = [ "10.10.10.2" ];
#       };
#     };
#   };
# };
# # With autobridging (default), creates: br0 bridging enp1s0, br1 bridging enp2s0
# ```
#
# ### Manual bridges with multiple interfaces:
# ```nix
# flake.hosts.hostname = {
#   networking = {
#     autobridging = false;
#     interfaces = {
#       enp1s0.ipv4 = [ "10.10.10.1" ];
#       enp2s0.ipv4 = [ "10.10.10.2" ];
#       enp3s0.ipv4 = [ "10.10.10.3" ];
#       enp4s0.ipv4 = [ "10.10.10.4" ];
#     };
#     bridges = {
#       "br0" = [ "enp1s0" "enp2s0" ];  # Multiple interfaces in one bridge (uses enp1s0's IPs)
#       "br1" = [ "enp3s0" ];            # Single interface bridge
#     };
#     # enp4s0 will be configured as standalone
#   };
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
  flake.features.networking.system =
    { hostOptions, ... }:
    {
      networking = {
        hostName = hostOptions.hostname;
      };
    };

  flake.features.networking.linux =
    {
      config,
      hostOptions,
      environment,
      activeFeatures,
      lib,
      ...
    }:
    with lib;
    let
      # Use networking config from hostOptions
      netCfg = hostOptions.networking;

      # Extract subnet mask from default network CIDR (e.g., "10.9.0.0/16" -> "/16")
      managementSubnet = "/${last (splitString "/" environment.networks.default.cidr)}";

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
      mkNetworkConfig = ipv4Addrs: ipv6Addrs: {
        networkConfig = {
          # Add subnet mask to IPv4 addresses if they don't have one
          Address =
            (map (
              addr: if elem "/" (stringToCharacters addr) then addr else "${addr}${managementSubnet}"
            ) ipv4Addrs)
            ++ ipv6Addrs;
          DHCP = if length ipv4Addrs > 0 then "ipv6" else "yes"; # enable DHCPv6 only if we have static IPv4, otherwise full DHCP
          IPv6AcceptRA = true; # for Stateless IPv6 Autoconfiguration (SLAAC)
          IPv6PrivacyExtensions = "yes";
          LinkLocalAddressing = "ipv6";
          DNS = environment.networks.default.dnsServers;
          DNSOverTLS = true;
          DNSSEC = "allow-downgrade";
        };
        dhcpV6Config = {
          UseDelegatedPrefix = true; # Request a prefix for our LANs.
          PrefixDelegationHint = "::/64";
        };
        routes = optionals (length ipv4Addrs > 0) [
          (mkRoute environment.networks.default.gatewayIp { })
          (mkRoute environment.networks.default.gatewayIpV6 {
            Destination = "::/0";
            GatewayOnLink = true; # it's a gateway on local link.
          })
        ];
        linkConfig.RequiredForOnline = "routable";
      };

      # The effective bridges configuration (auto-generate if autobridging is enabled)
      effectiveBridges =
        if netCfg.autobridging && netCfg.bridges == { } then
          listToAttrs (imap0 (idx: ifName: mkNameValue "br${toString idx}" [ ifName ]) allInterfaceNames)
        else
          netCfg.bridges;

      # All interface names from hostOptions.networking.interfaces
      allInterfaceNames = attrNames netCfg.interfaces;

      # Convert bridge attrset to list with additional metadata
      bridgeConfig = map (brName: {
        name = brName;
        interfaces = effectiveBridges.${brName};
        # Get IP addresses from the first interface in the bridge
        ipv4Addrs =
          if length effectiveBridges.${brName} > 0 then
            (netCfg.interfaces.${head effectiveBridges.${brName}}.ipv4 or [ ])
          else
            [ ];
        ipv6Addrs =
          if length effectiveBridges.${brName} > 0 then
            (netCfg.interfaces.${head effectiveBridges.${brName}}.ipv6 or [ ])
          else
            [ ];
      }) (attrNames effectiveBridges);

      # List of all bridge names
      bridgeNames = map (br: br.name) bridgeConfig;

      # Set of all interfaces that are part of bridges
      bridgedInterfaces = unique (concatMap (br: br.interfaces) bridgeConfig);

      # All interfaces we know about
      allInterfaces = unique (allInterfaceNames ++ bridgedInterfaces);

      # Interfaces that should be configured as standalone (not bridged)
      standaloneInterfaces = subtractLists bridgedInterfaces allInterfaceNames;

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
        map (
          ifName:
          mkNameValue ifName (
            {
              enable = true;
              matchConfig.Name = ifName;
            }
            // (mkNetworkConfig (netCfg.interfaces.${ifName}.ipv4 or [ ]) (
              netCfg.interfaces.${ifName}.ipv6 or [ ]
            ))
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
            // (mkNetworkConfig br.ipv4Addrs br.ipv6Addrs)
          )
        ) bridgeConfig
      );

      networkManagerEnabled = elem "network-manager" activeFeatures;

      # Effective list of interfaces to exclude from NetworkManager
      unmanagedInterfaces =
        if netCfg.unmanagedInterfaces != [ ] then
          netCfg.unmanagedInterfaces
        else
          allInterfaces ++ bridgeNames;
    in
    {
      config = {

        boot.kernelModules = [
          "tun" # TUN/TAP networking
          "bridge" # Network bridging
          "macvtap" # MacVTap networking
        ];

        networking = {
          domain = "${environment.name}.${environment.domain}";
          hostId = with builtins; substring 0 8 (hashString "md5" config.networking.hostName);

          networkmanager = {
            enable = lib.mkForce networkManagerEnabled;
            unmanaged = unmanagedInterfaces;
          };

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

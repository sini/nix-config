# Networking Configuration Module
#
# Generates systemd-networkd config from host.networking options.
# Supports static IPs, DHCP, bridges, bonds, and managed/unmanaged interfaces.
{
  features.networking.system =
    { host, ... }:
    {
      networking = {
        hostName = host.hostname;
      };
    };

  features.networking.linux =
    {
      config,
      host,
      environment,
      lib,
      ...
    }:
    with lib;
    let
      netCfg = host.networking;

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

      # ======================================================================
      # Network config generator
      # ======================================================================

      # Resolve effective DHCP mode for an interface
      effectiveDhcp =
        ifCfg:
        if ifCfg.dhcp != null then
          ifCfg.dhcp
        else if !(ifCfg.managed or true) then
          "none"
        else if length (ifCfg.ipv4 or [ ]) > 0 then
          "ipv6"
        else
          "yes";

      # Resolve effective link-local mode
      effectiveLinkLocal =
        ifCfg:
        if ifCfg.linkLocal != null then
          ifCfg.linkLocal
        else if ifCfg.managed or true then
          "ipv6"
        else
          "no";

      # Resolve effective requiredForOnline
      effectiveRequiredForOnline =
        ifCfg: if ifCfg.requiredForOnline != null then ifCfg.requiredForOnline else "routable";

      # Build network config for a managed interface (env gateway/DNS/subnet)
      mkManagedNetworkConfig =
        ifCfg:
        let
          ipv4Addrs = ifCfg.ipv4 or [ ];
          ipv6Addrs = ifCfg.ipv6 or [ ];
          dhcp = effectiveDhcp ifCfg;
        in
        {
          networkConfig = {
            Address = ipv4Addrs ++ ipv6Addrs;
            DHCP = dhcp;
            IPv6AcceptRA = true;
            IPv6PrivacyExtensions = "yes";
            LinkLocalAddressing = effectiveLinkLocal ifCfg;
            DNS = environment.networks.default.dnsServers;
            DNSOverTLS = true;
            DNSSEC = "allow-downgrade";
          };
          dhcpV6Config = {
            UseDelegatedPrefix = true;
            PrefixDelegationHint = "::/64";
          };
          routes = optionals (length ipv4Addrs > 0) [
            (mkRoute environment.networks.default.gatewayIp { })
            (mkRoute environment.networks.default.gatewayIpV6 {
              Destination = "::/0";
              GatewayOnLink = true;
            })
          ];
          linkConfig = {
            RequiredForOnline = effectiveRequiredForOnline ifCfg;
          }
          // optionalAttrs (ifCfg.mtu != null) {
            MTUBytes = toString ifCfg.mtu;
          };
        };

      # Build network config for an unmanaged interface (no env gateway/DNS)
      mkUnmanagedNetworkConfig =
        ifCfg:
        let
          ipv4Addrs = ifCfg.ipv4 or [ ];
          ipv6Addrs = ifCfg.ipv6 or [ ];
          dhcp = effectiveDhcp ifCfg;
        in
        {
          networkConfig = {
            Address = ipv4Addrs ++ ipv6Addrs;
            LinkLocalAddressing = effectiveLinkLocal ifCfg;
          }
          // optionalAttrs (dhcp != "none") {
            DHCP = dhcp;
          };
          linkConfig = {
            ActivationPolicy = "up";
            RequiredForOnline = effectiveRequiredForOnline ifCfg;
          }
          // optionalAttrs (ifCfg.mtu != null) {
            MTUBytes = toString ifCfg.mtu;
          };
        };

      # Dispatch to managed or unmanaged config
      mkNetworkConfig =
        ifCfg:
        if ifCfg.managed or true then mkManagedNetworkConfig ifCfg else mkUnmanagedNetworkConfig ifCfg;

      # ======================================================================
      # Interface classification
      # ======================================================================

      allInterfaceNames = attrNames netCfg.interfaces;

      # Bridge configuration
      effectiveBridges =
        if netCfg.autobridging && netCfg.bridges == { } then
          listToAttrs (imap0 (idx: ifName: mkNameValue "br${toString idx}" [ ifName ]) allInterfaceNames)
        else
          netCfg.bridges;

      bridgeConfig = map (brName: {
        name = brName;
        interfaces = effectiveBridges.${brName};
        ifCfg =
          if length effectiveBridges.${brName} > 0 then
            (netCfg.interfaces.${head effectiveBridges.${brName}} or {
              ipv4 = [ ];
              ipv6 = [ ];
            }
            )
          else
            {
              ipv4 = [ ];
              ipv6 = [ ];
            };
      }) (attrNames effectiveBridges);

      bridgeNames = map (br: br.name) bridgeConfig;
      bridgedInterfaces = unique (concatMap (br: br.interfaces) bridgeConfig);

      # Bond configuration
      bondConfig = mapAttrsToList (bondName: bondCfg: {
        name = bondName;
        inherit (bondCfg) interfaces mode transmitHashPolicy;
        ifCfg =
          netCfg.interfaces.${bondName} or {
            ipv4 = [ ];
            ipv6 = [ ];
          };
      }) (netCfg.bonds or { });

      bondNames = map (b: b.name) bondConfig;
      bondedInterfaces = unique (concatMap (b: b.interfaces) bondConfig);

      # Standalone: not bridged, not bonded, not a virtual device name
      standaloneInterfaces = subtractLists (
        bridgedInterfaces ++ bondedInterfaces ++ bridgeNames ++ bondNames
      ) allInterfaceNames;

      # All known interfaces (physical + virtual)
      allInterfaces = unique (allInterfaceNames ++ bridgedInterfaces ++ bridgeNames ++ bondNames);

      # ======================================================================
      # Netdev generation
      # ======================================================================

      bridgeNetdevs = listToAttrs (
        map (
          br:
          mkNameValue br.name {
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

      bondNetdevs = listToAttrs (
        map (
          bond:
          mkNameValue bond.name {
            netdevConfig = {
              Name = bond.name;
              Kind = "bond";
            };
            bondConfig = {
              Mode = bond.mode;
            }
            // optionalAttrs (bond.transmitHashPolicy != null) {
              TransmitHashPolicy = bond.transmitHashPolicy;
            };
          }
        ) bondConfig
      );

      # ======================================================================
      # Network generation
      # ======================================================================

      # Physical interfaces enslaved to bridges
      bridgedInterfaceNetworks = listToAttrs (
        concatMap (
          br:
          map (
            ifName:
            mkNameValue ifName {
              enable = true;
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

      # Physical interfaces enslaved to bonds
      bondSlaveNetworks = listToAttrs (
        concatMap (
          bond:
          map (
            ifName:
            mkNameValue ifName {
              enable = true;
              matchConfig.Name = ifName;
              networkConfig.Bond = bond.name;
              linkConfig.RequiredForOnline = "enslaved";
            }
          ) bond.interfaces
        ) bondConfig
      );

      # Bridge device networks (IP assignment)
      bridgeNetworks = listToAttrs (
        map (
          br:
          mkNameValue br.name (
            {
              enable = true;
              matchConfig.Name = br.name;
            }
            // (mkNetworkConfig br.ifCfg)
          )
        ) bridgeConfig
      );

      # Bond device networks (IP assignment)
      bondDeviceNetworks = listToAttrs (
        map (
          bond:
          mkNameValue bond.name (
            {
              enable = true;
              matchConfig.Name = bond.name;
            }
            // (mkNetworkConfig bond.ifCfg)
          )
        ) bondConfig
      );

      # Standalone interface networks
      standaloneInterfaceNetworks = listToAttrs (
        map (
          ifName:
          mkNameValue ifName (
            {
              enable = true;
              matchConfig.Name = ifName;
            }
            // (mkNetworkConfig netCfg.interfaces.${ifName})
          )
        ) standaloneInterfaces
      );

      networkManagerEnabled = host.hasFeature "network-manager";
    in
    {
      config = {

        boot.kernelModules = [
          "tun"
          "bridge"
          "macvtap"
          "bonding"
        ];

        networking = {
          domain = "${environment.name}.${environment.domain}";
          hostId = with builtins; substring 0 8 (hashString "md5" config.networking.hostName);

          useNetworkd = true;

          networkmanager = {
            enable = lib.mkForce networkManagerEnabled;
            unmanaged = allInterfaces ++ bridgeNames ++ bondNames;
          };

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
          netdevs = bridgeNetdevs // bondNetdevs;
          links = bridgeLinks;
          networks =
            bridgedInterfaceNetworks
            // bondSlaveNetworks
            // standaloneInterfaceNetworks
            // bridgeNetworks
            // bondDeviceNetworks;
        };
      };
    };
}

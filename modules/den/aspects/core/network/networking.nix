{
  den,
  lib,
  ...
}:
{
  den.aspects.core.network.networking = {
    nixos =
      { environment, host, ... }:
      let
        inherit (lib)
          attrNames
          concatMap
          imap0
          length
          listToAttrs
          map
          mapAttrsToList
          optionalAttrs
          optionals
          subtractLists
          unique
          ;

        netCfg = host.networking;

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

        effectiveLinkLocal =
          ifCfg:
          if ifCfg.linkLocal != null then
            ifCfg.linkLocal
          else if ifCfg.managed or true then
            "ipv6"
          else
            "no";

        effectiveRequiredForOnline =
          ifCfg: if ifCfg.requiredForOnline != null then ifCfg.requiredForOnline else "routable";

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
              DNS = (environment.networks.default or { }).dnsServers or [ ];
              DNSOverTLS = true;
              DNSSEC = "allow-downgrade";
            };
            dhcpV6Config = {
              UseDelegatedPrefix = true;
              PrefixDelegationHint = "::/64";
            };
            routes =
              let
                defaultNet = environment.networks.default or { };
              in
              optionals (length ipv4Addrs > 0) [
                (mkRoute (defaultNet.gatewayIp or null) { })
                (mkRoute (defaultNet.gatewayIpV6 or null) {
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
              (netCfg.interfaces.${builtins.head effectiveBridges.${brName}} or {
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
      in
      {
        boot.kernelModules = [
          "tun"
          "bridge"
          "macvtap"
          "bonding"
        ];

        networking = {
          hostName = host.name;
          domain = "${host.environment}.${environment.domain}";
          hostId = builtins.substring 0 8 (builtins.hashString "md5" host.name);

          useNetworkd = true;
          useDHCP = false;

          networkmanager = {
            enable = lib.mkForce (host.hasAspect den.aspects.core.network.manager);
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

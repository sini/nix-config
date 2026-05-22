{ den, lib, ... }:
{
  den.aspects.network.networking = {
    nixos =
      { config, host, ... }:
      let
        inherit (lib)
          attrNames
          attrValues
          concatMap
          filter
          head
          imap0
          length
          listToAttrs
          map
          mapAttrsToList
          mkForce
          optionalAttrs
          optionals
          subtractLists
          unique
          ;

        netCfg = host.networking;

        mkNameValue = name: value: { inherit name value; };

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
              # TODO: wire environment.networks.default.dnsServers once environment ref lands
              DNSOverTLS = true;
              DNSSEC = "allow-downgrade";
            };
            dhcpV6Config = {
              UseDelegatedPrefix = true;
              PrefixDelegationHint = "::/64";
            };
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

        standaloneInterfaces = subtractLists (
          bondedInterfaces ++ bondNames
        ) allInterfaceNames;

        allInterfaces = unique (allInterfaceNames ++ bondedInterfaces ++ bondNames);

        # ======================================================================
        # Netdev generation
        # ======================================================================

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
          hostId = builtins.substring 0 8 (builtins.hashString "md5" host.name);

          useNetworkd = true;
          useDHCP = false;

          networkmanager = {
            enable = mkForce false;
            unmanaged = allInterfaces;
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
          netdevs = bondNetdevs;
          networks =
            bondSlaveNetworks
            // standaloneInterfaceNetworks
            // bondDeviceNetworks;
        };
      };
  };
}

{ den, lib, ... }:
{
  den.aspects.networking = {
    includes = lib.attrValues den.aspects.networking._;

    _ = {
      # systemd-networkd based network configuration
      # Generates network config from host.networking metadata
      config = den.lib.perHost (
        { host }:
        {
          nixos =
            { config, lib, ... }:
            with lib;
            let
              netCfg = host.networking or { };
              interfaces = netCfg.interfaces or { };
              hostEnvironment = host.environment or { };
              defaultNetwork = (hostEnvironment.networks or { }).default or { };
              dnsServers = defaultNetwork.dnsServers or [ ];
              gatewayIp = defaultNetwork.gatewayIp or null;
              gatewayIpV6 = defaultNetwork.gatewayIpV6 or null;
              envName = hostEnvironment.name or "local";
              envDomain = hostEnvironment.domain or "local";

              mkRoute =
                gateway: extra:
                {
                  Gateway = gateway;
                  InitialCongestionWindow = 50;
                  InitialAdvertisedReceiveWindow = 50;
                }
                // extra;

              # Resolve effective DHCP mode for an interface
              effectiveDhcp =
                ifCfg:
                if ifCfg.dhcp or null != null then
                  ifCfg.dhcp
                else if !(ifCfg.managed or true) then
                  "none"
                else if length (ifCfg.ipv4 or [ ]) > 0 then
                  "ipv6"
                else
                  "yes";

              effectiveLinkLocal =
                ifCfg:
                if ifCfg.linkLocal or null != null then
                  ifCfg.linkLocal
                else if ifCfg.managed or true then
                  "ipv6"
                else
                  "no";

              effectiveRequiredForOnline =
                ifCfg: if ifCfg.requiredForOnline or null != null then ifCfg.requiredForOnline else "routable";

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
                    DNSOverTLS = true;
                    DNSSEC = "allow-downgrade";
                  }
                  // optionalAttrs (dnsServers != [ ]) {
                    DNS = dnsServers;
                  };
                  dhcpV6Config = {
                    UseDelegatedPrefix = true;
                    PrefixDelegationHint = "::/64";
                  };
                  routes =
                    optionals (length ipv4Addrs > 0 && gatewayIp != null) [
                      (mkRoute gatewayIp { })
                    ]
                    ++ optionals (length ipv4Addrs > 0 && gatewayIpV6 != null) [
                      (mkRoute gatewayIpV6 {
                        Destination = "::/0";
                        GatewayOnLink = true;
                      })
                    ];
                  linkConfig = {
                    RequiredForOnline = effectiveRequiredForOnline ifCfg;
                  }
                  // optionalAttrs (ifCfg.mtu or null != null) {
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
                  // optionalAttrs (ifCfg.mtu or null != null) {
                    MTUBytes = toString ifCfg.mtu;
                  };
                };

              mkNetworkConfig =
                ifCfg:
                if ifCfg.managed or true then mkManagedNetworkConfig ifCfg else mkUnmanagedNetworkConfig ifCfg;

              # Interface classification
              allInterfaceNames = attrNames interfaces;
              mkNameValue = name: value: { inherit name value; };

              effectiveBridges =
                if (netCfg.autobridging or false) && (netCfg.bridges or { }) == { } then
                  listToAttrs (imap0 (idx: ifName: mkNameValue "br${toString idx}" [ ifName ]) allInterfaceNames)
                else
                  netCfg.bridges or { };

              bridgeConfig = map (brName: {
                name = brName;
                interfaces = effectiveBridges.${brName};
                ifCfg =
                  if length effectiveBridges.${brName} > 0 then
                    (interfaces.${head effectiveBridges.${brName}} or {
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

              bondConfig = mapAttrsToList (bondName: bondCfg: {
                name = bondName;
                inherit (bondCfg) interfaces mode transmitHashPolicy;
                ifCfg =
                  interfaces.${bondName} or {
                    ipv4 = [ ];
                    ipv6 = [ ];
                  };
              }) (netCfg.bonds or { });

              bondNames = map (b: b.name) bondConfig;
              bondedInterfaces = unique (concatMap (b: b.interfaces) bondConfig);

              standaloneInterfaces = subtractLists (
                bridgedInterfaces ++ bondedInterfaces ++ bridgeNames ++ bondNames
              ) allInterfaceNames;

              allInterfaces = unique (allInterfaceNames ++ bridgedInterfaces ++ bridgeNames ++ bondNames);

              # Netdev generation
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

              # Network generation
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
                    // (mkNetworkConfig interfaces.${ifName})
                  )
                ) standaloneInterfaces
              );
            in
            {
              config = mkIf (interfaces != { }) {
                boot.kernelModules = [
                  "tun"
                  "bridge"
                  "macvtap"
                  "bonding"
                ];

                networking = {
                  domain = "${envName}.${envDomain}";
                  hostId = with builtins; substring 0 8 (hashString "md5" config.networking.hostName);

                  useNetworkd = true;
                  useDHCP = false;

                  networkmanager = {
                    enable = lib.mkForce false;
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
      );
    };
  };
}

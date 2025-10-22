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
      managementSubnet =
        let
          cidrParts = splitString "/" environment.networks.management.cidr;
        in
        "/${elemAt cidrParts 1}";

      # Generate bridge names: br0, br1, br2, etc.
      bridgeNames = imap0 (idx: _: "br${toString idx}") cfg.interfaces;

      # Create netdev configurations for bridges
      bridgeNetdevs =
        bridgeNames
        |> map (brName: {
          name = brName;
          value = {
            # https://wiki.archlinux.org/title/Systemd-networkd#Inherit_MAC_address_(optional)
            # Mac address should come from the bridged interface
            netdevConfig = {
              Name = brName;
              Kind = "bridge";
              MACAddress = "none";
            };
          };
        })
        |> listToAttrs;

      bridgeLinks =
        bridgeNames
        |> map (brName: {
          name = brName;
          value = {
            matchConfig.Name = brName;
            linkConfig.MACAddressPolicy = "none";
          };
        })
        |> listToAttrs;

      # Network configurations for physical interfaces (bind to bridges)
      networkdInterfaces =
        imap0 (idx: ifName: {
          name = ifName;
          value = {
            enable = true;
            matchConfig.Name = ifName;
            networkConfig.Bridge = elemAt bridgeNames idx;
            linkConfig.RequiredForOnline = "enslaved";
          };
        }) cfg.interfaces
        |> listToAttrs;

      # Network configurations for bridges (DHCP and IPv6)
      bridgeNetworks =
        imap0 (idx: brName: {
          name = brName;
          value = {
            enable = true;
            matchConfig.Name = brName;
            networkConfig = {
              Address = [ "${elemAt hostOptions.ipv4 idx}${managementSubnet}" ];
              # DHCP = "ipv4";
              DHCP = "ipv6"; # enable DHCPv6 only, so we can get a GUA.
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
              {
                # Destination = "0.0.0.0/0";
                Gateway = environment.gatewayIp;
                # Larger TCP window sizes, courtesy of
                # https://wiki.archlinux.org/title/Systemd-networkd#Speeding_up_TCP_slow-start
                InitialCongestionWindow = 50;
                InitialAdvertisedReceiveWindow = 50;
              }
              {
                Destination = "::/0";
                Gateway = environment.gatewayIpV6;
                GatewayOnLink = true; # it's a gateway on local link.
                InitialCongestionWindow = 50;
                InitialAdvertisedReceiveWindow = 50;
              }
            ];
            linkConfig.RequiredForOnline = "routable";
          };
        }) bridgeNames
        |> listToAttrs;
    in
    {
      options.hardware.networking = with types; {
        interfaces = mkOption {
          type = listOf str;
          default = [ "enp1s0" ];
          description = ''
            List of interfaces to configure using systemd-networkd.
            A bridge will be created for each interface (br0, br1, br2, etc.).
          '';
        };

        bridges = mkOption {
          type = listOf str;
          readOnly = true;
          default = bridgeNames;
          description = ''
            List of bridge interface names automatically generated for each interface.
            This option is read-only and computed from the interfaces list.
          '';
        };

        enableNetworkManager = mkEnableOption "Enable NetworkManager for managing network interfaces";

        unmanagedInterfaces = mkOption {
          type = listOf str;
          default = cfg.interfaces ++ cfg.bridges;
          defaultText = "hardware.networking.interfaces";
          description = ''
            List of interfaces to mark as unmanaged by NetworkManager.
            Defaults to the same value as `interfaces`.
          '';
        };
      };

      config = {
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

        systemd.network = {
          enable = true;
          wait-online.enable = false;
          netdevs = bridgeNetdevs;
          links = bridgeLinks;
          networks = networkdInterfaces // bridgeNetworks;
        };
      };
    };
}

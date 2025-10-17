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

      # Get the current hostname to lookup host configuration
      hostname = config.networking.hostName;
      hostConfig = config.flake.hosts.${hostname} or { };
      hostIPv6 = hostConfig.ipv6 or [ ];

      # Generate bridge names: br0, br1, br2, etc.
      bridgeNames = imap0 (idx: _: "br${toString idx}") cfg.interfaces;

      # Create netdev configurations for bridges
      bridgeNetdevs =
        bridgeNames
        |> map (brName: {
          name = brName;
          value = {
            netdevConfig = {
              Kind = "bridge";
              Name = brName;
            };
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
            networkConfig = {
              Bridge = elemAt bridgeNames idx;
            };
          };
        }) cfg.interfaces
        |> listToAttrs;

      # Network configurations for bridges (DHCP and IPv6)
      bridgeNetworks =
        bridgeNames
        |> map (brName: {
          name = brName;
          value = {
            enable = true;
            matchConfig.Name = brName;
            networkConfig = {
              DHCP = "ipv4";
              IPv6AcceptRA = true;
              IPv6SendRA = false;
            };
            dhcpV6Config = {
              UseDelegatedPrefix = true;
              PrefixDelegationHint = "::/64";
            };
            ipv6AcceptRAConfig = {
              UseDNS = true;
              DHCPv6Client = "always";
            };
            address = hostIPv6;
            extraConfig = ''
              [DHCPv6]
              UseDelegatedPrefix=true
              PrefixDelegationHint=::/64
            '';
          };
        })
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
          networks = networkdInterfaces // bridgeNetworks;
        };
      };
    };
}

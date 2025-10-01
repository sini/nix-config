{
  flake.aspects.networking.nixos =
    {
      config,
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

      networkdInterfaces =
        cfg.interfaces
        |> map (ifName: {
          name = ifName;
          value = {
            enable = true;
            matchConfig.Name = ifName;
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

      unmanagedInterfaces = cfg.unmanagedInterfaces |> map (ifName: "interface-name:${ifName}");

    in
    {
      options.hardware.networking = with types; {
        interfaces = mkOption {
          type = listOf str;
          default = [ "enp1s0" ];
          description = ''
            List of interfaces to configure using systemd-networkd.
          '';
        };

        enable_networkManager = mkEnableOption "Enable NetworkManager for managing network interfaces";

        unmanagedInterfaces = mkOption {
          type = listOf str;
          default = cfg.interfaces;
          defaultText = "hardware.networking.interfaces";
          description = ''
            List of interfaces to mark as unmanaged by NetworkManager.
            Defaults to the same value as `interfaces`.
          '';
        };
      };

      config = {
        networking = {
          useDHCP = false;
          dhcpcd.enable = false;

          firewall = {
            enable = true;
            allowPing = true;
            logRefusedConnections = false;
          };

          networkmanager = {
            unmanaged = unmanagedInterfaces;
          };
        };

        systemd.services.NetworkManager-wait-online.enable = false;

        systemd.network = {
          enable = true;
          wait-online.enable = false;
          networks = networkdInterfaces;
        };
      };
    };
}

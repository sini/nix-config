{
  flake.features.networking.nixos =
    {
      config,
      lib,
      hostOptions,
      environment,
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
          networks = networkdInterfaces;
        };
      };
    };
}

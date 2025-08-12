{
  flake.modules.nixos.networking =
    { config, lib, ... }:
    with lib;
    let
      cfg = config.hardware.networking;

      networkdInterfaces =
        cfg.interfaces
        |> map (ifName: {
          name = ifName;
          value = {
            enable = true;
            matchConfig.Name = ifName;
            networkConfig.DHCP = "yes";
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
          firewall.enable = false; # TODO: enable firewall
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

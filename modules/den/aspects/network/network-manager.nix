{ den, ... }:
{
  den.aspects.network.network-manager = {
    nixos =
      {
        pkgs,
        ...
      }:
      {
        networking.networkmanager = {
          enable = true;
          wifi.powersave = true;
          settings = {
            connectivity = {
              enabled = false;
            };
          };
          plugins = [
            pkgs.networkmanager-openvpn
          ];
        };

        systemd.services.NetworkManager-wait-online.enable = false;
      };

    provides.impermanence.nixos = {
      environment.persistence."/cache".directories = [
        "/etc/NetworkManager/system-connections"
        "/var/lib/NetworkManager"
      ];
    };
  };
}

{
  features.network-manager = {
    linux =
      {
        pkgs,
        ...
      }:
      {
        config = {
          networking.networkmanager = {
            enable = true;
            # unmanaged list is set by networking.nix from all known interfaces
            wifi.powersave = true;
            settings = {
              connectivity = {
                enabled = false;
              };
            };
            plugins = with pkgs; [
              networkmanager-openvpn
            ];
          };

          systemd.services.NetworkManager-wait-online.enable = false;
        };
      };

    provides.impermanence.linux = {
      environment.persistence."/cache".directories = [
        "/etc/NetworkManager/system-connections"
        "/var/lib/NetworkManager"
      ];
    };
  };
}

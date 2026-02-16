{
  flake.features.network-manager.nixos =
    { config, pkgs, ... }:
    let
      unmanagedInterfaces =
        config.hardware.networking.unmanagedInterfaces |> map (ifName: "interface-name:${ifName}");
    in
    {
      config = {
        networking.networkmanager = {
          enable = true;
          unmanaged = unmanagedInterfaces;
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

        environment.persistence."/cache".directories = [
          "/etc/NetworkManager/system-connections"
          "/var/lib/NetworkManager"
        ];
      };
    };
}

{
  flake.features.network-manager.nixos =
    {
      config,
      ...
    }:
    let
      cfg = config.hardware.networking;
      unmanagedInterfaces = cfg.unmanagedInterfaces |> map (ifName: "interface-name:${ifName}");
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
        };

        systemd.services.NetworkManager-wait-online.enable = false;

        environment.persistence."/cache".directories = [
          "/etc/NetworkManager/system-connections"
          "/var/lib/NetworkManager"
        ];
      };
    };
}

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
        };

        systemd.services.NetworkManager-wait-online.enable = false;

        environment.persistence."/volatile".directories = [ "/etc/NetworkManager/system-connections" ];
      };
    };
}

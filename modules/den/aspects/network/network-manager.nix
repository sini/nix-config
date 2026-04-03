{ den, lib, ... }:
{
  den.aspects.network-manager = {
    includes = lib.attrValues den.aspects.network-manager._;

    _ = {
      config = den.lib.perHost {
        nixos =
          { pkgs, ... }:
          {
            networking.networkmanager = {
              enable = true;
              wifi.powersave = true;
              settings = {
                connectivity.enabled = false;
              };
              plugins = with pkgs; [
                networkmanager-openvpn
              ];
            };

            systemd.services.NetworkManager-wait-online.enable = false;
          };
      };

      impermanence = den.lib.perHost {
        cache.directories = [
          "/etc/NetworkManager/system-connections"
          "/var/lib/NetworkManager"
        ];
      };
    };
  };
}

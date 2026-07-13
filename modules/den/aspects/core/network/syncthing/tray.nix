{ ... }:
{
  den.aspects.core.network.syncthing.tray = {
    homeManager =
      { config, pkgs, ... }:
      {
        services.syncthing.tray = {
          enable = true;
          package = pkgs.syncthingtray;
        };

        # Pre-configure Syncthing Tray to connect to our local Unix socket.
        # This requires Qt 6.8+ to support the `unix+http` URL scheme and `localPath`.
        xdg.configFile."syncthingtray.ini".text = ''
          [tray]
          connections\size=1
          connections\1\label=Local
          connections\1\syncthingUrl=unix+http://localhost
          connections\1\localPath=${config.home.homeDirectory}/.cache/syncthing.sock
        '';
      };
  };
}

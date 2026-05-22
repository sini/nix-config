{ den, ... }:
{
  den.aspects.apps.jellyfin-client = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.jftui
          pkgs.jellyfin-tui
          pkgs.jellyfin-media-player
          pkgs.jellyfin-mpv-shim
        ];
      };
  };
}

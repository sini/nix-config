{ den, ... }:
{
  den.aspects.jellyfin-client = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          jftui
          jellyfin-tui
          jellyfin-media-player
          jellyfin-mpv-shim
        ];
      };
  };
}

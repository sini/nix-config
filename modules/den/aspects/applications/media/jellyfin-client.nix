{
  den.aspects.applications.media.jellyfin-client = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.jftui
          pkgs.jellyfin-tui
          pkgs.jellyfin-media-player
          # pkgs.jellyfin-mpv-shim # TODO: find an alternative...
        ];
      };

    persistHome.directories = [
      ".config/jellyfin-mpv-shim"
      ".config/jellyfin-tui"
      ".local/share/jellyfin-tui"
      ".local/share/jellyfin-desktop"
    ];
  };
}

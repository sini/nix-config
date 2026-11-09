{
  den.aspects.applications.media.jellyfin-client = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.jftui
          # shortcut: nixpkgs 20261107's cargo setup hook exports
          # LIBSQLITE3_SYS_USE_PKG_CONFIG=1, so sqlx-macros needs the system sqlite; drop
          # this override once nixpkgs' jellyfin-tui builds again.
          (pkgs.jellyfin-tui.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
            buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.sqlite ];
          }))
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

{

  flake.features.jellyfin-client.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        jftui
        jellyfin-tui
        jellyfin-media-player
        jellyfin-mpv-shim
      ];
    };
}

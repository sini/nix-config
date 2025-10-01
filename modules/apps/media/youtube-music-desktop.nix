{

  flake.aspects.youtube-music-desktop.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        ytmdesktop # YouTube Music desktop client
      ];
    };
}

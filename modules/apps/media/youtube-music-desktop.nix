{

  flake.modules.homeManager.youtube-music-desktop =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        ytmdesktop # YouTube Music desktop client
      ];
    };
}

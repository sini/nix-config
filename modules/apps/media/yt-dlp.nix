{

  flake.features.yt-dlp.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [ media-downloader ];
      programs.yt-dlp.enable = true;
    };
}

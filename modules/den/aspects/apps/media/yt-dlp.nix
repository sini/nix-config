_: {
  den.aspects.apps.yt-dlp = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.media-downloader ];
        programs.yt-dlp.enable = true;
      };
  };
}

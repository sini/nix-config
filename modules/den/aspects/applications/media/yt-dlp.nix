{
  den.aspects.applications.media.yt-dlp = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.media-downloader ];
        programs.yt-dlp.enable = true;
      };
  };
}

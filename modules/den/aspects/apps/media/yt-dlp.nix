{ den, ... }:
{
  den.aspects.yt-dlp = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [ media-downloader ];
        programs.yt-dlp.enable = true;
      };
  };
}

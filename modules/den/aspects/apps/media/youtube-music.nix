{
  den.aspects.apps.media.youtube-music = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.ytmdesktop
        ];
      };
  };
}

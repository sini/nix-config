_:
{
  den.aspects.apps.youtube-music = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.ytmdesktop
        ];
      };
  };
}

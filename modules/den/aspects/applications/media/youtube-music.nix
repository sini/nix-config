{
  den.aspects.applications.media.youtube-music = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          #pkgs.ytmdesktop # TODO: re-enable
        ];
      };
  };
}

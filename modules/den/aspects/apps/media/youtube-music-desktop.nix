{ den, ... }:
{
  den.aspects.youtube-music-desktop = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          ytmdesktop
        ];
      };
  };
}

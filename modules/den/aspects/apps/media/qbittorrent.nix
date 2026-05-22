{ den, ... }:
{
  den.aspects.apps.qbittorrent = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.qbittorrent
        ];
      };
  };
}

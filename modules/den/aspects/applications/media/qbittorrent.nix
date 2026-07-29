{
  den.aspects.applications.media.qbittorrent = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.qbittorrent
        ];
      };
  };
}

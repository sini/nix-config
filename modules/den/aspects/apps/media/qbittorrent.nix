_: {
  den.aspects.apps.media.qbittorrent = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.qbittorrent
        ];
      };
  };
}

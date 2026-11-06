{
  den.aspects.applications.media.qbittorrent = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.qbittorrent
        ];
      };

    persistHome.directories = [
      ".config/qBittorrent"
      ".local/share/qBittorrent"
    ];
  };
}

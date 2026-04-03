{ den, ... }:
{
  den.aspects.qbittorrent = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          qbittorrent
        ];
      };
  };
}

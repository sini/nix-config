{
  flake.features.qbittorrent.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        qbittorrent
      ];
    };
}

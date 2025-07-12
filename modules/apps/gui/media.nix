{
  flake.modules.homeManager.media =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        ytmdesktop # YouTube Music desktop client
      ];
    };
}

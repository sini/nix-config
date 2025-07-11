{
  flake.modules.homeManager.obsidian =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [ obsidian ];
    };
}

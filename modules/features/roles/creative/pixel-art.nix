{
  features.pixel-art.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        aseprite
        libresprite
        goxel
        blockbench
      ];
    };
}

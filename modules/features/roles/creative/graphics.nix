{
  features.graphics.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        blender
        krita
        gimp
        inkscape
      ];
    };
}

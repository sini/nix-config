{
  flake.features.cad.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kicad # Electronics
        freecad-wayland # 3D Design
        openscad # 3D Design
        orca-slicer # 3D Printing
      ];
    };
}

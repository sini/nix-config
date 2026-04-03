# CAD role: electronics and 3D design tools.
{ den, lib, ... }:
{
  den.aspects.cad = {
    includes = lib.attrValues den.aspects.cad._;

    _ = {
      packages = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = with pkgs; [
              kicad # Electronics
              freecad-wayland # 3D Design
              openscad # 3D Design
              orca-slicer # 3D Printing
            ];
          };
      };
    };
  };
}

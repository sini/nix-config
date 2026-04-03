# Graphics: 2D/3D art and design tools.
{ den, lib, ... }:
{
  den.aspects.graphics = {
    includes = lib.attrValues den.aspects.graphics._;

    _ = {
      packages = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = with pkgs; [
              blender
              krita
              gimp
              inkscape
            ];
          };
      };
    };
  };
}

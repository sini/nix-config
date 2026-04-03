# Pixel art: sprite editing and voxel tools.
{ den, lib, ... }:
{
  den.aspects.pixel-art = {
    includes = lib.attrValues den.aspects.pixel-art._;

    _ = {
      packages = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = with pkgs; [
              aseprite
              libresprite
              goxel
              blockbench
            ];
          };
      };
    };
  };
}

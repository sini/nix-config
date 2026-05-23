_:
{
  den.aspects.roles.creative.pixel-art = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.aseprite
          pkgs.libresprite
          pkgs.goxel
          pkgs.blockbench
        ];
      };
  };
}

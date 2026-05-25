_: {
  den.aspects.roles.creative.pixel-art = {
    colmena-tags = [ "creative" ];
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

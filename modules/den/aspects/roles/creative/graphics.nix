_: {
  den.aspects.roles.creative.graphics = {
    colmena = [ "creative" ];
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.blender
          pkgs.krita
          pkgs.gimp
          pkgs.inkscape
        ];
      };
  };
}

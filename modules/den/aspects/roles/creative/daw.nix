_: {
  den.aspects.roles.creative.daw = {
    colmena-tags = [ "creative" ];
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.reaper
          pkgs.ardour
          pkgs.audacity
          pkgs.sunvox
          pkgs.supercollider
        ];
      };
  };
}

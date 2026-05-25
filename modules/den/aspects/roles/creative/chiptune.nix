_: {
  den.aspects.roles.creative.chiptune = {
    colmena-tags = [ "creative" ];
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.alda
          pkgs.lenmus
          pkgs.milkytracker
          pkgs.famistudio
          pkgs.furnace
        ];
      };
  };
}

_:
{
  den.aspects.roles.creative.chiptune = {
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

# Chiptune: tracker and chiptune music tools.
{ den, lib, ... }:
{
  den.aspects.chiptune = {
    includes = lib.attrValues den.aspects.chiptune._;

    _ = {
      packages = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = with pkgs; [
              alda
              lenmus
              milkytracker
              famistudio
              furnace
            ];
          };
      };
    };
  };
}

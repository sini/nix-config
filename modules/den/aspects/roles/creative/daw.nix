# DAW: digital audio workstation and music production tools.
{ den, lib, ... }:
{
  den.aspects.daw = {
    includes = lib.attrValues den.aspects.daw._;

    _ = {
      packages = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = with pkgs; [
              reaper
              ardour
              audacity
              sunvox
              supercollider
            ];
          };
      };
    };
  };
}

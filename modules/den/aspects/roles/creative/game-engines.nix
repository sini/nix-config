# Game engines: Godot and level design tools.
{ den, lib, ... }:
{
  den.aspects.game-engines = {
    includes = lib.attrValues den.aspects.game-engines._;

    _ = {
      packages = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = with pkgs; [
              godot_4
              godot_4-export-templates-bin
              gdtoolkit_4
              ldtk
            ];
          };
      };
    };
  };
}

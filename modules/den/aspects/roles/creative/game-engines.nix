{
  den.aspects.roles.creative.game-engines = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.godot_4
          pkgs.godot_4-export-templates-bin
          pkgs.gdtoolkit_4
          pkgs.ldtk
        ];
      };
  };
}

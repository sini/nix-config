{
  features.game-engines.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        godot_4
        godot_4-export-templates-bin
        gdtoolkit_4
        ldtk
      ];
    };
}

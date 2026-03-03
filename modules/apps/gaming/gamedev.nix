{
  flake.features.gamedev = {
    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          godot_4
          godot_4-export-templates-bin
          gdtoolkit_4

          #unityhub
          # unity3d
          # ue4

          # TODO: blocked on cmake change, maybe try and fix it upstream?
          # rx # rx is a modern and minimalist pixel editor.

          ldtk # A modern 2D level editor from the director of Dead Cells.

          # images
          aseprite
          blender
          krita
          gimp
          inkscape
          libresprite
          goxel
          blockbench

          # DAW
          reaper
          ardour
          sunvox
          audacity
          alda
          lenmus
          milkytracker
          sonic-pi
          supercollider
          famistudio
          furnace
        ];
      };
  };
}

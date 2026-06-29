# Dock: auto-hiding, bottom-oriented, and — crucially for the aerospace tiling
# WM — spaces that never auto-rearrange.
{
  den.aspects.macos.defaults.dock.darwin = {
    system.defaults.dock = {
      autohide = true;
      # Reveal instantly instead of the default ~0.5s hover delay, and skip the
      # slide animation entirely.
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      # Faster Mission Control; scale (not genie) minimise.
      expose-animation-duration = 0.1;
      mineffect = "scale";
      orientation = "bottom";
      tilesize = 48;
      launchanim = true;
      mouse-over-hilite-stack = true;
      show-recents = false;
      # Keep Mission Control spaces in a fixed order; aerospace assigns windows
      # to specific workspaces and macOS reordering them breaks that mapping.
      mru-spaces = false;
    };
  };
}

{
  flake.aspects.hyprland.home = {
    wayland.windowManager.hyprland.settings.animations = {

      enabled = "yes";

      bezier = [
        "myBezier, 0.05, 0.9, 0.1, 1.05"
        "linear, 0.0, 0.0, 1.0, 1.0"
        "wind, 0.05, 0.9, 0.1, 1.05"
        "winIn, 0.1, 1.1, 0.1, 1.1"
        "winOut, 0.3, -0.3, 0, 1"
        "slow, 0, 0.85, 0.3, 1"
        "overshot, 0.7, 0.6, 0.1, 1.1"
        "bounce, 1.1, 1.6, 0.1, 0.85"
        "sligshot, 1, -1, 0.15, 1.25"
        "nice, 0, 6.9, 0.5, -4.20"
      ];

      animation = [
        "windowsIn, 1, 2, slow, popin"
        "windowsOut, 1, 2, winOut, popin"
        "windowsMove, 1, 1, wind, slide"
        "border, 1, 1, linear"
        "fade, 1, 3, overshot"
        "workspaces, 1, 3, wind"
        "windows, 1, 3, bounce, popin"
      ];

    };
  };
}

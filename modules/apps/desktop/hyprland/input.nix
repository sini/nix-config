{
  flake.modules.homeManager.hyprland = {
    wayland.windowManager.hyprland.settings = {

      device = [
        {
          name = "etd2303:00-04f3:3083-touchpad";
          sensitivity = "-0.15";
        }
      ];

      input = {
        accel_profile = "adaptive";
        kb_layout = "us";
        kb_options = "grp:win_space_toggle";
        numlock_by_default = true;
        repeat_delay = 275;
        repeat_rate = 35;
        sensitivity = -0.8;

        touchpad.natural_scroll = 1;

        touchdevice.output = "DP-1";
      };

      gestures = {
        workspace_swipe = 1;
        workspace_swipe_create_new = false;
      };

    };
  };
}

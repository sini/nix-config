{
  flake.features.hyprland.home = {
    wayland.windowManager.hyprland.settings = {
      input = {
        follow_mouse = 1;
        accel_profile = "flat";

        kb_layout = "us";
        numlock_by_default = true;

        touchpad = {
          disable_while_typing = true;
          natural_scroll = "no";
          tap-to-click = true;
        };

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
        scroll_factor = 1.0;
        emulate_discrete_scroll = 1;
        # repeat_delay = 500; # Mimic the responsiveness of mac setup
        # repeat_rate = 50; # Mimic the responsiveness of mac setup
        repeat_delay = 275;
        repeat_rate = 35;
      };

      # gestures = {
      #   workspace_swipe = true;
      #   workspace_swipe_create_new = false;
      #   workspace_swipe_fingers = 3;
      #   workspace_swipe_invert = false;
      # };
    };
  };
}

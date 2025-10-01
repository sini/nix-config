{
  flake.aspects.hyprland.home = {
    wayland.windowManager.hyprland.settings = {

      dwindle = {
        pseudotile = true;
        preserve_split = true;
        special_scale_factor = 0.85;
        force_split = 2;
      };

      general.resize_on_border = true;

      misc = {
        focus_on_activate = true;
        enable_swallow = true;
        # swallow_regex = "^(${vars.terminal.name})$";
        swallow_regex = "^(kitty)$";
      };

    };
  };
}

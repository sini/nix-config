{
  flake.modules.homeManager.hyprland =
    # let
    #   acolor1 = "rgb(c6a0f6)"; # #c6a0f6
    #   acolor2 = "rgb(8aadf4)"; # #8aadf4
    #   icolor1 = "rgb(5b6078)"; # #5b6078
    #   tcolor = "rgb(000000)"; # #000000
    #   active_border = "${acolor1} ${acolor2} 45deg";
    #   inactive_border = "${icolor1}";
    # in
    {
      wayland.windowManager.hyprland.settings = {

        general = {
          gaps_in = 2;
          gaps_out = 3;
          border_size = 2;

          # "col.active_border" = active_border;
          # "col.inactive_border" = inactive_border;
        };

        # group = {
        #   # "col.border_active" = active_border;
        #   # "col.border_inactive" = inactive_border;
        #   groupbar = {
        #     # text_color = tcolor;
        #     # "col.active" = acolor1;
        #     # "col.inactive" = icolor1;
        #   };
        # };

        decoration = {
          rounding = 3;
          inactive_opacity = 0.9;
          dim_special = 0.35;
          shadow.enabled = false;
          blur.enabled = false;
        };

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
        };

      };
    };
}

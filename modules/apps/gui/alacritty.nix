{
  flake.modules.homeManager.alacritty = {
    programs.alacritty = {
      enable = true;
      # https://alacritty.org/config-alacritty.html
      settings = {
        general.live_config_reload = true;
        window = {
          # TODO: for tiling WM's : none
          decorations = "full";
          dynamic_title = true;
          title = "Terminal";
        };
        bell = {
          # https://github.com/danth/stylix/discussions/1207
          # ideally this would be some stylix color theme color
          color = "#000000";
          duration = 200;
        };
      };
    };
  };
}

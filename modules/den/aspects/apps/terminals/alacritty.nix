{ den, ... }:
{
  den.aspects.apps.alacritty = {
    homeManager = {
      programs.alacritty = {
        enable = true;
        settings = {
          general.live_config_reload = true;
          window = {
            decorations = "full";
            dynamic_title = true;
            title = "Terminal";
          };
          bell = {
            color = "#000000";
            duration = 200;
          };
        };
      };
    };
  };
}

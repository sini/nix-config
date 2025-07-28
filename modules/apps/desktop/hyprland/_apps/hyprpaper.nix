{ vars, ... }:
{

  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "off";
      splash = false;
      preload = [ vars.wallpaper ];
      wallpaper = [ ",${vars.wallpaper}" ];
    };
  };

}

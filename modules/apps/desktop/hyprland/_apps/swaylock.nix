{ vars, ... }:
{

  programs.swaylock = {
    enable = true;
    settings = {
      daemonize = true;
      ignore-empty-password = true;
      indicator-caps-lock = true;

      # clock = true;
      # timestr = "%H:%M";
      # datestr = "%d %B, %a";

      # image = vars.wallpaper;
      # effect-blur = "20x3";
      # effect-greyscale = true;

      # grace = 3;
      # grace-no-mouse = true;
      # grace-no-touch = true;
      indicator-idle-visible = true;

      font = "${vars.terminal.font_name}";
      font-size = 35;
      color = "24273B";
      indicator-radius = 100;
      indicator-thickness = 10;
      inside-color = "ffffff00";
      key-hl-color = "5e81ac";
      layout-text-color = "d8dee9ff";
      line-uses-ring = true;
      ring-color = "2e3440";
      separator-color = "e5e9f022";
      text-caps-lock-color = "d8dee9ff";
      text-clear-color = "d8dee9ff";
      text-color = "d8dee9ff";
    };
  };

}

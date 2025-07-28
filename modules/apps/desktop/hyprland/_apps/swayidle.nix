{ pkgs, osConfig, ... }:
let
  uwsm = "${pkgs.uwsm}/bin/uwsm";
  prefix = if osConfig.programs.hyprland.withUWSM then "${uwsm} app --" else "";

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  swaylockPkg = pkgs.swaylock;
  swaylock = "${swaylockPkg}/bin/swaylock";
  # playerctl = "${pkgs.playerctl}/bin/playerctl";
  pidof = "${pkgs.procps}/bin/pidof";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  systemd-ac-power = "${pkgs.systemd}/bin/systemd-ac-power";

  lockCommand =
    # "${playerctl} -a pause || true && (${pidof} swaylock || ${swaylock})";
    "(${pidof} swaylock || ${prefix} ${swaylock})";
in
{

  wayland.windowManager.hyprland.settings = {
    windowrulev2 = [
      "idleinhibit focus, fullscreen:1"
      "idleinhibit always, fullscreen:1 class:firefox title:^(.*YouTube.*)$"
      "idleinhibit focus, class:firefox title:^(.*Miro.*)$"
      "idleinhibit always, class:Slack title:^(.*Huddle.*)$"
      "idleinhibit always, class:firefox title:^(Meet.*)$"
    ];

    misc = {
      key_press_enables_dpms = true;
      mouse_move_enables_dpms = true;
    };

  };

  services.swayidle = {
    enable = true;
    extraArgs = [ "-w" ];

    timeouts = [

      # ON AC
      {
        timeout = 150; # 2.5min
        command = "${systemd-ac-power} && ${brightnessctl} -s set 1000";
        resumeCommand = "${systemd-ac-power} && ${brightnessctl} -r";
      }

      {
        timeout = 300; # 5min
        command = "${systemd-ac-power} && ${lockCommand}";
      }

      {
        timeout = 330; # 5.5min
        command = "${systemd-ac-power} && ${hyprctl} dispatch dpms off";
        resumeCommand = "${systemd-ac-power} && ${hyprctl} dispatch dpms on";
      }

      {
        timeout = 1800; # 30min
        command = "${systemd-ac-power} && ${systemctl} suspend";
      }

      # ON BATTERY
      {
        timeout = 60; # 1min
        command = "${systemd-ac-power} || ${brightnessctl} -s set 1000";
        resumeCommand = "${systemd-ac-power} || ${brightnessctl} -r";
      }

      {
        timeout = 130; # 2.5min
        command = "${systemd-ac-power} || ${lockCommand}";
      }

      {
        timeout = 160; # 3min
        command = "${systemd-ac-power} || ${hyprctl} dispatch dpms off";
        resumeCommand = "${systemd-ac-power} || ${hyprctl} dispatch dpms on";
      }

      {
        timeout = 600; # 10min
        command = "${systemd-ac-power} || ${systemctl} suspend";
      }

    ];

    events = [
      {
        event = "lock";
        command = lockCommand;
      }

      {
        event = "before-sleep";
        command = lockCommand;
      }

      {
        event = "after-resume";
        command = "${hyprctl} dispatch dpms on";
      }
    ];
  };

}

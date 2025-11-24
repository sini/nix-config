{
  flake.features.hypridle.home =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.brightnessctl
      ];

      programs.hyprlock.enable = true;

      services.hypridle = {
        enable = true;

        settings = {
          general = {
            ignore_dbus_inhibit = false;
            lock_cmd = "pidof hyprlock || hyprlock";
            before_sleep_cmd = "loginctl lock-session";
            after_sleep_cmd = "hyprctl dispatch dpms on";
          };

          listener = [
            # 2 min - Turn off keyboard backlight
            # {
            #   timeout = 120;
            #   on-timeout = "brightnessctl -sd *::kbd_backlight set 0";
            #   on-resume = "brightnessctl -rd *::kbd_backlight";
            # }

            # 2 min - Dim screen brightness
            # {
            #   timeout = 120;
            #   on-timeout = "brightnessctl -s set 1";
            #   on-resume = "brightnessctl -r"; # restore
            # }

            # Lock screen after 5 minutes
            {
              timeout = 300;
              on-timeout = "loginctl lock-session";
            }
            # Turn off displays after 10 minutes
            {
              timeout = 600;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
          ];
        };
      };
    };

}

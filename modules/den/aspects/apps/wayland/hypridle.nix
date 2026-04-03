{ den, ... }:
{
  den.aspects.hypridle = den.lib.perUser {
    homeManager =
      {
        lib,
        pkgs,
        ...
      }:
      {
        home.packages = [
          pkgs.brightnessctl
        ];

        programs.hyprlock.enable = true;

        systemd.user.services.hypridle = {
          Unit = {
            ConditionEnvironment = lib.mkForce [
              "|XDG_CURRENT_DESKTOP=Hyprland"
              "|XDG_CURRENT_DESKTOP=niri"
            ];
            After = lib.mkForce [ "graphical-session.target" ];
            Requisite = [ "graphical-session.target" ];
          };

          Service = {
            Type = "dbus";
            BusName = "org.freedesktop.ScreenSaver";
            Slice = "background-graphical.slice";
          };
        };

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
  };
}

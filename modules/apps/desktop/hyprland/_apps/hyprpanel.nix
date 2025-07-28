{
  pkgs,
  lib,
  config,
  ...
}:
{

  sops.secrets."personal/weather-api" = { };

  wayland.windowManager.hyprland.settings.bind =
    let
      systemctl = "${pkgs.systemd}/bin/systemctl";
    in
    [ "SUPER, B, exec, ${systemctl} --user restart hyprpanel" ];

  systemd.user.services.hyprpanel.Service.Restart = lib.mkForce "always";

  programs.hyprpanel = {

    enable = true;
    systemd.enable = true;

    settings = {

      bar = {
        bluetooth = {
          label = true;
          rightClick = "${pkgs.blueman}/bin/blueman-manager";
        };
        clock.format = "%a %b %d %H:%M";
        launcher.autoDetectIcon = true;
        layouts = {
          "0" = {
            left = [
              "dashboard"
              "workspaces"
              "windowtitle"
            ];
            middle = [ "media" ];
            right = [
              "volume"
              "network"
              "bluetooth"
              "battery"
              "systray"
              "clock"
              "kbinput"
              "notifications"
            ];
          };
          "1" = {
            left = [ ];
            middle = [ ];
            right = [ ];
          };
          "2" = {
            left = [ ];
            middle = [ ];
            right = [ ];
          };
        };
        network = {
          rightClick = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          showWifiInfo = true;
        };
        notifications.show_total = false;
        windowtitle.custom_title = true;
        workspaces = {
          ignored = "-\\d+"; # hide special workspaces
          monitorSpecific = true;
          show_icons = true;
          show_numbered = false;
          workspaceMask = false;
        };
      };

      menus = {
        clock = {
          time.military = true;
          weather = {
            key = config.sops.secrets."personal/weather-api".path;
            location = "Budva";
            unit = "metric";
          };
        };
        dashboard.directories = {
          left = {
            directory1 = {
              command = "${pkgs.kitty}/bin/kitty -e ${pkgs.yazi}/bin/yazi ${config.home.homeDirectory}/Downloads";
              label = "󰉍 Downloads";
            };
            directory2 = {
              command = "${pkgs.kitty}/bin/kitty -e ${pkgs.yazi}/bin/yazi ${config.home.homeDirectory}/Videos";
              label = "󰉏 Videos";
            };
            directory3 = {
              command = "${pkgs.kitty}/bin/kitty -e ${pkgs.yazi}/bin/yazi ${config.home.homeDirectory}/repos";
              label = "󰚝 Projects";
            };
          };
          right = {
            directory1 = {
              command = "${pkgs.kitty}/bin/kitty -e ${pkgs.yazi}/bin/yazi ${config.home.homeDirectory}/Documents";
              label = "󱧶 Documents";
            };
            directory2 = {
              command = "${pkgs.kitty}/bin/kitty -e ${pkgs.yazi}/bin/yazi ${config.home.homeDirectory}/Pictures";
              label = "󰉏 Pictures";
            };
            directory3 = {
              command = "${pkgs.kitty}/bin/kitty -e ${pkgs.yazi}/bin/yazi ${config.home.homeDirectory}";
              label = "󱂵 Home";
            };
          };
        };
        power = {
          lowBatteryNotification = true;
          lowBatteryNotificationText = "Battery is running low - $POWER_LEVEL %";
          lowBatteryThreshold = 15;
        };
      };

      theme = {
        # NOTE: https://github.com/Jas-SinghFSU/HyprPanel/issues/1023#issuecomment-3000694765
        # name = "catppuccin_macchiato";
        bar = {
          buttons = {
            dashboard.icon = "#99c1f1";
            modules.kbLayout.enableBorder = false;
            workspaces.enableBorder = false;
          };
          floating = false;
          menus.menu = {
            clock.scaling = 85;
            dashboard.scaling = 80;
            notifications.scaling = 90;
          };
          scaling = 75;
        };
        notification.enableShadow = false;
        osd = {
          active_monitor = true;
          duration = 1000;
          location = "bottom";
          margins = "0px 0px 35px 0px";
          muted_zero = true;
          orientation = "horizontal";
        };
      };

    };

  };
}

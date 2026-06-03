{ den, ... }:
{
  den.aspects.apps.wayland.hyprpanel = {
    homeManager =
      {
        config,
        lib,
        host,
        pkgs,
        ...
      }:
      let
        inherit (pkgs)
          kitty
          yazi
          blueman
          networkmanagerapplet
          ;
        has_battery = host.hasAspect den.aspects.hardware.laptop;
      in
      {
        programs.hyprpanel = {
          enable = true;
          systemd.enable = true;
          settings = {
            bar = {
              layouts = {
                "0" = {
                  left = [
                    "dashboard"
                    "workspaces"
                  ];
                  middle = [ "media" ];
                  right =
                    let
                      base = [
                        "volume"
                        "network"
                        "bluetooth"
                      ];
                      extras = lib.optionals has_battery [ "battery" ];
                      end = [
                        "systray"
                        "clock"
                        "notifications"
                      ];
                    in
                    base ++ extras ++ end;
                };
              };
            };
            launcher.autoDetectIcon = true;
            bluetooth = {
              label = true;
              rightClick = "${blueman}/bin/blueman-manager";
            };
            network = {
              rightClick = "${networkmanagerapplet}/bin/nm-connection-editor";
              showWifiInfo = true;
            };
            notifications.show_total = false;
            windowtitle.custom_title = true;
            workspaces = {
              ignored = "-\\d+";
              monitorSpecific = true;
              show_icons = true;
              show_numbered = false;
              workspaceMask = false;
            };

            menus = {
              clock = {
                time = {
                  military = true;
                  hideSeconds = true;
                };
                weather.unit = "metric";
              };
              dashboard = {
                directories = {
                  enabled = true;
                  left = {
                    directory1 = {
                      command = "${kitty}/bin/kitty -e ${yazi}/bin/yazi ${config.home.homeDirectory}/Downloads";
                      label = "󰉍 Downloads";
                    };
                    directory2 = {
                      command = "${kitty}/bin/kitty -e ${yazi}/bin/yazi ${config.home.homeDirectory}/Videos";
                      label = "󰉏 Videos";
                    };
                    directory3 = {
                      command = "${kitty}/bin/kitty -e ${yazi}/bin/yazi ${config.home.homeDirectory}/repos";
                      label = "󰚝 Projects";
                    };
                  };
                  right = {
                    directory1 = {
                      command = "${kitty}/bin/kitty -e ${yazi}/bin/yazi ${config.home.homeDirectory}/Documents";
                      label = "󱧶 Documents";
                    };
                    directory2 = {
                      command = "${kitty}/bin/kitty -e ${yazi}/bin/yazi ${config.home.homeDirectory}/Pictures";
                      label = "󰉏 Pictures";
                    };
                    directory3 = {
                      command = "${kitty}/bin/kitty -e ${yazi}/bin/yazi ${config.home.homeDirectory}";
                      label = "󱂵 Home";
                    };
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
              font = {
                name = "DejaVuSansM Nerd Font Mono";
                size = "12px";
              };
              bar = {
                buttons = {
                  modules.kbLayout.enableBorder = false;
                  workspaces.enableBorder = false;
                };
                floating = false;
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
      };
  };
}

{
  flake.features.swaync.home =
    {
      pkgs,
      config,
      ...
    }:
    let
      accent = "#${config.lib.stylix.colors.base0D}";
      background = "#${config.lib.stylix.colors.base00}";
      foreground = "#${config.lib.stylix.colors.base05}";
      borderSize = 5;
      nerdFont = config.stylix.fonts.sansSerif.name;
      theme = pkgs.writeTextFile {
        name = "swayosd-css";
        text = ''
          window#osd {
            padding: 12px 18px;
            border-radius: 999px;
            border: solid ${toString borderSize}px ${accent};
            background: alpha(${background}, 0.99);
          }

          #container {
            margin: 0px;
          }

          image {
            font-family: "${nerdFont}";
            font-size: 14px;
            color: ${foreground};
          }

          label {
            color: ${foreground};
          }

          progressbar:disabled,
          image:disabled {
            opacity: 0.5;
          }

          progressbar {
            min-width: 150px;
            min-height: 5px;
            border-radius: 999px;
            background: transparent;
            border: none;
          }

          trough {
            min-height: inherit;
            border-radius: inherit;
            border: none;
            background: alpha(${accent},0.3);
          }

          progress {
            min-height: inherit;
            border-radius: inherit;
            border: none;
            background: ${accent};
          }
        '';
      };
    in
    {
      # services.swaync = {
      #   enable = true;
      #   # systemd.enable = true;
      #   # systemd.target = "graphical-session.target";

      #   settings = {
      #     # General settings
      #     cssPriority = "user";
      #     image-visibility = "when-available";
      #     keyboard-shortcut = true;
      #     relative-timestamps = true;
      #     timeout = 5;
      #     timeout-low = 5;
      #     timeout-critical = 0;
      #     script-fail-notify = true;
      #     transition-time = 200;

      #     # Layer settings
      #     layer-shell = true;
      #     layer = "overlay";
      #     control-center-layer = "overlay";

      #     # Notification settings
      #     positionX = "right";
      #     positionY = "top";
      #     notification-2fa-action = true;
      #     notification-inline-replies = false;
      #     notification-icon-size = 32;
      #     notification-body-image-height = 100;
      #     notification-body-image-width = 200;
      #     notification-window-width = 300;

      #     # Control center settings
      #     control-center-positionX = "right";
      #     control-center-positionY = "top";
      #     control-center-margin-top = 4;
      #     control-center-margin-bottom = 4;
      #     control-center-margin-left = 0;
      #     control-center-margin-right = 4;
      #     control-center-width = 500;
      #     control-center-exclusive-zone = true;
      #     fit-to-screen = true;
      #     hide-on-action = true;
      #     hide-on-clear = false;

      #     # Widget settings
      #     widgets = [
      #       "title"
      #       "dnd"
      #       "notifications"
      #       "mpris"
      #     ];

      #     # Widget config
      #     widget-config = {
      #       title = {
      #         text = "Notifications";
      #         clear-all-button = true;
      #         button-text = "Clear All";
      #       };
      #       dnd = {
      #         text = "Do Not Disturb";
      #       };
      #       mpris = {
      #         image-size = 96;
      #         image-radius = 12;
      #         blur = true;
      #       };
      #     };
      #   };

      #   # style = lib.mkAfter ''
      #   #   /*** Global ***/
      #   #   progress,
      #   #   progressbar,
      #   #   trough {
      #   #     border-radius: 16px;
      #   #   }

      #   #   .app-icon,
      #   #   .image {
      #   #     -gtk-icon-effect: none;
      #   #   }

      #   #   .notification-action {
      #   #     border-radius: 5px;
      #   #     margin: 0.5rem;
      #   #   }

      #   #   .close-button {
      #   #     margin: 0.5rem;
      #   #     padding: 0.25rem;
      #   #     border-radius: 5px;
      #   #   }

      #   #   /*** Notifications ***/
      #   #   .notification-group.collapsed
      #   #     .notification-row:not(:last-child)
      #   #     .notification-action,
      #   #   .notification-group.collapsed
      #   #     .notification-row:not(:last-child)
      #   #     .notification-default-action {
      #   #     opacity: 0;
      #   #   }

      #   #   /*** Control Center ***/
      #   #   .control-center {
      #   #     border-radius: 8px;
      #   #     padding: 2rem;
      #   #   }

      #   #   .control-center-list {
      #   #     background: transparent;
      #   #   }

      #   #   /*** Widgets ***/
      #   #   /* Title widget */
      #   #   .widget-title {
      #   #     margin: 0.5rem;
      #   #   }

      #   #   .widget-title > label {
      #   #     font-weight: bold;
      #   #   }

      #   #   .widget-title > button {
      #   #     border-radius: 8px;
      #   #     padding: 0.5rem;
      #   #   }

      #   #   /* DND Widget */
      #   #   .widget-dnd {
      #   #     margin: 0.5rem;
      #   #   }

      #   #   .widget-dnd > label {
      #   #     font-weight: bold;
      #   #   }

      #   #   .widget-dnd > switch {
      #   #     border-radius: 8px;
      #   #   }

      #   #   .widget-dnd > switch slider {
      #   #     border-radius: 8px;
      #   #     padding: 0.25rem;
      #   #   }

      #   #   /* Mpris widget */
      #   #   .widget-mpris .widget-mpris-player {
      #   #     border-radius: 8px;
      #   #     margin: 0.5rem;
      #   #     padding: 0.5rem;
      #   #   }

      #   #   .widget-mpris .widget-mpris-player .widget-mpris-album-art {
      #   #     border-radius: 16px;
      #   #   }

      #   #   .widget-mpris .widget-mpris-player .widget-mpris-title {
      #   #     font-weight: bold;
      #   #   }

      #   #   .widget-mpris .widget-mpris-player .widget-mpris-subtitle {
      #   #     font-weight: normal;
      #   #   }

      #   #   .widget-mpris .widget-mpris-player > box > button {
      #   #     border: 1px solid transparent;
      #   #     border-radius: 8px;
      #   #     padding: 0.25rem;
      #   #   }
      #   # '';

      # };

      # wayland.windowManager.hyprland.settings = {
      #   exec-once = ["swayosd-server"];
      #   bind = [",XF86AudioMute, exec, ${pkgs.swayosd}/bin/swayosd-client --output-volume mute-toggle"];
      #   bindl = [
      #     ",XF86MonBrightnessUp, exec, ${pkgs.swayosd}/bin/swayosd-client --brightness raise 5%+"
      #     ",XF86MonBrightnessDown, exec, ${pkgs.swayosd}/bin/swayosd-client --brightness lower 5%-"
      #     "$mod,F2,exec, ${pkgs.swayosd}/bin/swayosd-client --brightness 100"
      #     "$mod,F3,exec, ${pkgs.swayosd}/bin/swayosd-client --brightness 0"
      #     ",XF86AudioPlay, exec, ${pkgs.swayosd}/bin/swayosd-client --playerctl play-pause"
      #     ",XF86AudioNext, exec, ${pkgs.swayosd}/bin/swayosd-client --playerctl next"
      #     ",XF86AudioPrev, exec, ${pkgs.swayosd}/bin/swayosd-client --playerctl previous"
      #   ];
      #   bindle = [
      #     ",XF86AudioRaiseVolume, exec, ${pkgs.swayosd}/bin/swayosd-client --output-volume +2 --max-volume=100"
      #     ",XF86AudioLowerVolume, exec, ${pkgs.swayosd}/bin/swayosd-client --output-volume -2"
      #   ];
      #   bindr = [
      #     "CAPS,Caps_Lock,exec,${pkgs.swayosd}/bin/swayosd-client --caps-lock"
      #     ",Scroll_Lock,exec,${pkgs.swayosd}/bin/swayosd-client --scroll-lock"
      #     ",Num_Lock,exec,${pkgs.swayosd}/bin/swayosd-client --num-lock"
      #   ];
      # };

      services.swayosd = {
        enable = true;
        stylePath = theme;
      };

      services.swaync = {
        enable = true;
        settings = {
          control-center-layer = "top";
          control-center-width = 400;
          control-center-height = 400;
          control-center-margin-top = 10;
          control-center-margin-bottom = 250;
          control-center-margin-right = 10;

          notification-window-width = 380;
          notification-icon-size = 48;
          notification-body-image-height = 80;
          notification-body-image-width = 160;
          notification-2fa-action = true;
          notification-grouping = false;

          image-visibility = "when-available";
          transition-time = 100;

          widgets = [
            "title"
            "buttons-grid"
            "dnd"
            "inhibitors"
            "mpris"
            "notifications"
          ];

          widget-config = {
            inhibitors = {
              text = "Inhibitors";
              button-text = "Clear All";
              clear-all-button = true;
            };
            title = {
              text = "Notifications";
              clear-all-button = true;
              button-text = "Clear All";
            };
            dnd = {
              text = "Do Not Disturb";
            };
            mpris = {
              image-size = 64;
              blur = true;
            };
            buttons-grid = {
              actions = [
                {
                  label = "󰐥";
                  command = "systemctl poweroff";
                }
                {
                  label = "󰜉";
                  command = "systemctl reboot";
                }
                {
                  label = "󰒲";
                  command = "systemctl suspend";
                }
                {
                  label = "󰌾";
                  command = "lock";
                }
                {
                  label = "󰍃";
                  command = "${pkgs.hyprland}/bin/hyprctl dispatch exit";
                }
                {
                  label = "󰕾";
                  command = "${pkgs.swayosd}/bin/swayosd-client --output-volume mute-toggle";
                }
                {
                  label = "󰍬";
                  command = "${pkgs.swayosd}/bin/swayosd-client --input-volume mute-toggle";
                }
                {
                  label = "󰂯";
                  command = "${pkgs.blueman}/bin/blueman-manager";
                }
                {
                  label = "󰹑";
                  command = "screenshot region";
                }
                # {
                #   label = "";
                #   command = "${pkgs.kooha}/bin/kooha";
                # }
                # {
                #   label = "";
                #   command = "caffeine";
                # }
                {
                  label = "󰋱";
                  command = "hyprfocus-toggle";
                }
              ];
            };
          };
        };
        style = ''
          .notification,
          .notification.low,
          .notification.normal,
          .notification.critical,
          .notification-default-action,
          .notification-default-action:hover,
          .notification-default-action:active,
          .notification-row:focus,
          .notification-group:focus,
          .notification-group.collapsed .notification-row .notification,
          .control-center .notification-row .notification-background,
          .control-center .notification-row .notification-background:hover,
          .control-center .notification-row .notification-background:active {
            background: transparent;
            border: none;
            outline: none;
            box-shadow: none;
            margin: 0;
            padding: 0;
          }

          .control-center {
            background: @base00;
            border: 1px solid @base0D;
            color: @base05;
            padding: 5px;
            border-radius: 15px;
          }

          .widget-body, .widget-mpris, .widget-dnd, .widget-inhibitors {
            margin: 4px 5px;
          }

          .notification-content {
            border-radius: 12px;
            padding: 10px;
            margin: 8px;
          }

          .notification-title {
            font-weight: bold;
            color: @base05;
          }

          .close-button {
            margin: 6px;
            padding: 3px;
            border-radius: 100px;
            background-color: transparent;
            border: 1px solid transparent;
          }

          .close-button:hover {
            background-color: @base0C;
          }

          .close-button:active {
            background-color: @base0C;
            color: @base00;
          }
        '';
      };
    };
}

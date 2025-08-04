{
  flake.modules.homeManager.hyprland =
    {
      inputs,
      config,
      pkgs,
      ...
    }:
    let
      overview = inputs.hyprland-overview.packages.${pkgs.system}.Hyprspace;
      easymotion = inputs.hyprland-easymotion.packages.${pkgs.system}.hyprland-easymotion;
      hyprsplit = inputs.hyprsplit.packages.${pkgs.system}.hyprsplit;
      split-monitor-workspaces =
        inputs.hyprland-split-monitor-workspaces.packages.${pkgs.system}.split-monitor-workspaces;
    in
    {

      imports = [
        inputs.hyprland.homeManagerModules.default
      ];

      home.packages = with pkgs; [
        hyprpicker
        hyprcursor
        libnotify
        networkmanagerapplet # bin: nm-connection-editor
        blueman # bin: blueman-manager
        pwvucontrol
        snapshot
      ];

      xdg.configFile."uwsm/env".source =
        "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

      programs.wofi.enable = true;

      wayland.windowManager.hyprland = {
        enable = true;
        # Disabled because it conflicts with uwsm
        # https://wiki.hypr.land/Useful-Utilities/Systemd-start/
        systemd.enable = false;

        xwayland.enable = true;

        plugins =
          with inputs.hyprland-plugins.packages.${pkgs.system};
          [
            # hyprbars
            hyprexpo
            # hyprtrails
            # hyprwinwrap
          ]
          ++ [
            easymotion
            overview
            hyprsplit
            split-monitor-workspaces
          ];

        settings = {
          exec-once = [
            "uwsm finalize"
          ];
          ecosystem = {
            #enforce_permissions = true;
            no_donation_nag = true;
          };
          misc = {
            vrr = 1;
            disable_hyprland_logo = true;
          };
          monitor = [ ",highres,auto,1" ];
          xwayland.force_zero_scaling = true;

        };
      };

      # programs.waybar = {
      #   enable = true;
      # }

      # systemd.user.services.hyprpanel = {
      #   Unit = {
      #     Description = "Hyprpanel";
      #     PartOf = [ "hyprland-session.target" ];
      #     After = [ "hyprland-session.target" ];
      #   };
      #   Install = {
      #     WantedBy = [ "hyprland-session.target" ];
      #   };
      #   Service = {
      #     ExecStart = "${pkgs.hyprpanel}/bin/hyprpanel";
      #     Restart = "always";
      #     Type = "simple";
      #   };
      # };

      programs.hyprpanel = {
        enable = true;
        systemd.enable = false; # Manually configure systemd unit...
        settings = {
          bar = {
            layouts = {
              "0" = {
                left = [
                  "dashboard"
                  "workspaces"
                ];
                middle = [ "media" ];
                right = [
                  "volume"
                  "network"
                  "bluetooth"
                  "battery"
                  "systray"
                  "clock"
                  "notifications"
                ];
              };
              # "1" = {
              #   left = [ ];
              #   middle = [ ];
              #   right = [ ];
              # };
              # "2" = {
              #   left = [ ];
              #   middle = [ ];
              #   right = [ ];
              # };
            };
          };
          launcher.autoDetectIcon = true;
          bluetooth = {
            label = true;
            rightClick = "${pkgs.blueman}/bin/blueman-manager";
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

          menus = {
            clock = {
              time = {
                military = true;
                hideSeconds = true;
              };
              weather.unit = "metric";
            };
            dashboard = {
              stats.enable_gpu = true;
              directories = {
                enabled = true;
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
            # NOTE: https://github.com/Jas-SinghFSU/HyprPanel/issues/1023#issuecomment-3000694765
            # name = "catppuccin_macchiato";
            bar = {
              buttons = {
                dashboard.icon = "#99c1f1";
                modules.kbLayout.enableBorder = false;
                workspaces.enableBorder = false;
              };
              floating = false;
              # menus.menu = {
              #   clock.scaling = 85;
              #   dashboard.scaling = 80;
              #   notifications.scaling = 90;
              # };
              # scaling = 75;
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
}

{
  flake.features.waybar.home =
    {
      lib,
      pkgs,
      activeFeatures,
      config,
      ...
    }:
    let
      isLaptop = lib.elem "laptop" activeFeatures;
    in
    {
      systemd.user.services.waybar = {
        Unit.ConditionExec = [
          "${pkgs.bash}/bin/bash -c '[[ \"$XDG_CURRENT_DESKTOP\" = niri || \"$XDG_CURRENT_DESKTOP\" = Hyprland ]]'"
        ];
        Service.Slice = "background-graphical.slice";
      };

      programs.waybar = {
        enable = true;
        systemd.enable = true;
        systemd.target = "graphical-session.target";

        settings = {
          mainBar = {
            name = "main";
            id = "main";
            layer = "top";
            position = "top";
            exclusive = true;
            fixed-center = true;
            gtk-layer-shell = true;
            margin-top = 7;
            margin-left = 7;
            margin-right = 7;
            margin-bottom = 0;

            height = 32;
            spacing = 8;

            modules-left = [
              "niri/workspaces"
              "hyprland/workspaces"
              "hyprland/submap"
            ];

            modules-center = [
              "hyprland/window"
              "niri/window"
            ];

            modules-right = [
              "network"
              "network#wifi"
              "idle_inhibitor"
              "wireplumber#sink"
              "wireplumber#source"
              "cpu"
              # "backlight"
            ]
            ++ (lib.optional isLaptop "battery")
            ++ [
              "mpris"
              "tray"
              "clock"
              "custom/notification"
            ];

            "niri/workspaces" = {
              format = "{value}";
              format-icons = {
                active = "";
                default = "";
              };
            };

            "niri/window" = {
              "icon" = true;
              "icon-size" = 16;
              "format" = " {title}";
              "on-scroll-down" = "niri msg action focus-column-right";
              "on-scroll-up" = "niri msg action focus-column-left";
            };

            "hyprland/workspaces" = {
              format = "{icon}";
              format-icons = {
                active = "";
                default = "";
                persistent = "";
              };
              on-scroll-up = "hyprctl dispatch workspace r-1";
              on-scroll-down = "hyprctl dispatch workspace r+1";
              all-outputs = false;
              persistent_workspaces = {
                "*" = 5;
              };
            };

            "hyprland/window" = {
              "icon" = true;
              "icon-size" = 24;
              "format" = " {title}";
            };

            # "hyprland/workspaces" = {
            #   all-outputs = false;
            #   disable-click = false;
            #   disable-scroll = false;
            #   format = "{name}";
            # };
            # "niri/workspaces" = {
            #   all-outputs = false;
            #   disable-click = false;
            #   disable-scroll = false;
            #   format = "{name:.3}";
            # };

            battery = {
              format = "{icon}";
              "format-icons" = [
                ""
                ""
                ""
                ""
                ""
              ];
              states = {
                critical = 20;
              };
              tooltip-format = ''
                Capacity: {capacity}%
                {timeTo}
                Draw: {power} watts.'';
            };

            clock = {
              format = "{:%a %e %b  %I:%M %p}";
              interval = 1;
              tooltip-format = "<tt><small>{calendar}</small></tt>";
              "calendar" = {
                "weeks-pos" = "left";
                "format" = {
                  "months" = "<span color='#eee'>{}</span>";
                  "days" = "<span color='#eee'>{}</span>";
                  "weeks" = "<span color='#888'>{}</span>";
                  "today" = "<span color='#eee'><b><u>{}</u></b></span>";
                };
              };
              "actions" = {
                "on-scroll-up" = "shift_up";
                "on-scroll-down" = "shift_down";
              };
            };

            "custom/notification" = {
              tooltip = false;
              format = "{icon}";
              format-icons = {
                notification = "<span foreground='red'><sup></sup></span>";
                none = "";
                dnd-notification = "<span foreground='red'><sup></sup></span>";
                dnd-none = "";
                inhibited-notification = "<span foreground='red'><sup></sup></span>";
                inhibited-none = "";
                dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
                dnd-inhibited-none = "";
              };
              return-type = "json";
              exec-if = "which swaync-client";
              exec = "swaync-client -swb";
              on-click = "swaync-client -t";
              escape = true;
            };

            idle_inhibitor = {
              format = "{icon}";
              format-icons = {
                activated = "";
                deactivated = "";
              };
            };

            "group/indicators" = {
              modules = [
                "memory"
                "cpu"
              ];
              orientation = "inherit";
            };

            "cpu" = {
              "format" = "{icon}";
              "tooltip-format" = "{usage:3}%";
              "format-icons" = [
                ""
                "<span color='#6d9'></span>"
                "<span color='#fd2'></span>"
                "<span color='#f94'></span>"
                "<span color='#f55'></span>"
              ];
              "interval" = 2;
            };

            "memory" = {
              "format" = "{icon}";
              "tooltip-format" = ''
                Total: {total:.1f} GiB
                Total swap: {swapTotal:.1f} GiB

                Used: {used:.1f} GiB
                Used swap: {swapUsed:.1f} GiB

                Free: {avail:.1f} GiB
                Free swap: {swapAvail:.1f} GiB'';
              "format-icons" = [
                ""
                ""
                ""
                ""
                ""
                ""
                ""
                "<span color='#fd2'></span>"
                "<span color='#f94'></span>"
                "<span color='#f55'></span>"
              ];
              "interval" = 5;
            };

            mpris = {
              dynamic-order = [
                "artist"
                "title"
                "album"
                "position"
                "length"
              ];
              format-paused = " 󰐊 ";
              format-playing = " 󰏤 ";
              format-stopped = " 󰓛 ";
            };

            # "custom/logo" = {
            #   format = "    ";
            #   tooltip = false;
            # };

            tray = {
              icon-size = 24;
              spacing = 6;
              reverse-direction = true;
            };

            "wireplumber#sink" = {
              format = "{icon} {volume:03d}";
              max-volume = 150;
              on-click = "'${lib.getExe pkgs.pwvucontrol}'";
              node-type = "Audio/Sink";
              tooltip = true;
              tooltip-format = "{node_name}: {volume}%";
            };
            "wireplumber#source" = {
              format = "{icon} {volume:03d}";
              max-volume = 150;
              on-click = "'${lib.getExe pkgs.pwvucontrol}'";
              node-type = "Audio/Source";
              tooltip = true;
              tooltip-format = "{node_name}: {volume}%";
            };
            network = {
              interface = lib.mkDefault "br*";
              format-wifi = lib.mkDefault " {bandwidthDownOctets:>}  {bandwidthUpOctets:>} {essid} ({signalStrength}%) ";
              format-ethernet = lib.mkDefault " {bandwidthDownOctets:>}  {bandwidthUpOctets:>} {ipaddr}/{cidr} ";
              tooltip-format = lib.mkDefault "{ifname} via {gwaddr} ";
              format-linked = lib.mkDefault "{ifname} (No IP) 󰲛";
              format-disconnected = lib.mkDefault "";
              format-alt = lib.mkDefault "{ifname}: {ipaddr}/{cidr}";
              interval = 1;
            };
            "network#wifi" = {
              interface = lib.mkDefault "wlan*";
              format-wifi = lib.mkDefault " {bandwidthDownOctets:>}  {bandwidthUpOctets:>} {essid} ({signalStrength}%) ";
              format-ethernet = lib.mkDefault " {bandwidthDownOctets:>}  {bandwidthUpOctets:>} {ipaddr}/{cidr} ";
              tooltip-format = lib.mkDefault "{ifname} via {gwaddr} ";
              format-linked = lib.mkDefault "{ifname} (No IP) ";
              format-disconnected = lib.mkDefault "";
              format-alt = lib.mkDefault "{ifname}: {ipaddr}/{cidr}";
              interval = 1;
            };
          };
        };

        style = lib.mkAfter ''
          * {
            font-family: ${config.stylix.fonts.serif.name}, sans-serif;
          }

          #workspaces button {
            padding: 0px;
            border-bottom: 0px none transparent;
          }

          #niri-workspaces.empty,
          #hyprland-workspaces.empty {
            padding: 0;
            margin: 0;
            border: none;
            background: none;
            min-width: 0;
          }

          #custom-notification {
            font-size: 20px;
            font-weight: bolder;
            padding-left: 20px;
            padding-right: 24px;
          }
        '';
        # window#waybar.empty #window {
        #   padding: 0;
        #   margin: 0;
        #   background: none;
        #   border: none;
        #   min-width: 0;
        # }
      };
    };

}

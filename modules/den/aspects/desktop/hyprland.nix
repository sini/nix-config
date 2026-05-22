{ den, inputs, ... }:
{
  den.aspects.desktop.hyprland = {
    nixos =
      {
        pkgs,
        lib,
        ...
      }:
      {
        environment.systemPackages = [
          pkgs.xwayland-satellite
          pkgs.wlogout
          pkgs.swaylock
        ];

        nix.settings = {
          substituters = [ "https://hyprland.cachix.org" ];
          trusted-substituters = [ "https://hyprland.cachix.org" ];
          trusted-public-keys = [
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          ];
        };

        environment.sessionVariables = {
          NIXOS_OZONE_WL = "1";
          GSK_RENDERER = "cairo";
        };

        programs.hyprland = {
          enable = true;
          package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
          portalPackage =
            inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
          withUWSM = true;
          xwayland.enable = true;
        };

        systemd.user.services.hyprpolkitagent = {
          path = lib.mkForce [ ];
          serviceConfig.Slice = "session-graphical.slice";
          wantedBy = [ "graphical-session.target" ];
        };

        services = {
          dbus = {
            implementation = "broker";
            packages = [
              pkgs.gcr
              pkgs.gnome-settings-daemon
            ];
          };

          gnome.gnome-keyring.enable = true;
          gnome.sushi.enable = true;
          devmon.enable = true;
          gvfs.enable = true;
          udisks2.enable = true;
        };
      };

    homeManager =
      {
        config,
        lib,
        pkgs,
        osConfig,
        ...
      }:
      let
        inherit (pkgs)
          brightnessctl
          hyprshot
          elogind
          playerctl
          swappy
          wl-clipboard
          wireplumber
          wofi
          ;
        uwsm = "${pkgs.uwsm}/bin/uwsm";
        prefix = if osConfig.programs.hyprland.withUWSM then "${uwsm} app --" else "";

        term = "${prefix} kitty";
        editor = "nvim";

        brightnessctlBin = "${brightnessctl}/bin/brightnessctl";
        hyprshotBin = "${hyprshot}/bin/hyprshot";
        loginctl = "${elogind}/bin/loginctl";
        playerctlBin = "${playerctl}/bin/playerctl";
        swappyBin = "${swappy}/bin/swappy";
        wl-paste = "${wl-clipboard}/bin/wl-paste";
        wpctl = "${wireplumber}/bin/wpctl";

        PRIMARY = "SUPER";
        SECONDARY = "SHIFT";
        TERTIARY = "CTRL";
      in
      {
        imports = [
          inputs.hyprland.homeManagerModules.default
        ];

        home.packages = [
          pkgs.hyprpicker
          pkgs.hyprcursor
          pkgs.libnotify
          pkgs.networkmanagerapplet
          pkgs.blueman
          pkgs.pwvucontrol
          pkgs.snapshot
          pkgs.split-monitor-workspaces
        ];

        xdg.configFile."uwsm/env".source =
          "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

        programs = {
          wofi.enable = true;
          rofi.enable = true;
        };

        systemd.user.services.hyprpolkitagent = {
          Unit.ConditionEnvironment = lib.mkForce [
            "|XDG_CURRENT_DESKTOP=Hyprland"
            "|XDG_CURRENT_DESKTOP=niri"
          ];
        };

        systemd.user.services.hyprpaper = {
          Unit.ConditionEnvironment = lib.mkForce [
            "|XDG_CURRENT_DESKTOP=Hyprland"
            "|XDG_CURRENT_DESKTOP=niri"
          ];
          Service.Slice = "background-graphical.slice";
        };

        services.hyprpaper = {
          enable = true;
          settings = {
            ipc = "on";
            splash = false;
          };
        };

        # XDG mime associations
        xdg = {
          configFile."mimeapps.list".force = true;
          mimeApps =
            let
              editorApps = [ "nvim.desktop" ];
              browser = [ "firefox.desktop" ];
              imageViewer = [ "org.gnome.Loupe.desktop" ];
              pdfViewer = [ "org.pwmt.zathura.desktop" ];
              associations = {
                "text/x-dbus-service" = editorApps;
                "image/jpeg" = imageViewer;
                "image/png" = imageViewer;
                "image/gif" = imageViewer;
                "image/webp" = imageViewer;
                "image/tiff" = imageViewer;
                "image/x-tga" = imageViewer;
                "image/vnd-ms.dds" = imageViewer;
                "image/x-dds" = imageViewer;
                "image/bmp" = imageViewer;
                "image/vnd.microsoft.icon" = imageViewer;
                "image/vnd.radiance" = imageViewer;
                "image/x-exr" = imageViewer;
                "image/x-portable-bitmap" = imageViewer;
                "image/x-portable-graymap" = imageViewer;
                "image/x-portable-pixmap" = imageViewer;
                "image/x-portable-anymap" = imageViewer;
                "image/x-qoi" = imageViewer;
                "image/svg+xml" = imageViewer;
                "image/svg+xml-compressed" = imageViewer;
                "image/avif" = imageViewer;
                "image/heic" = imageViewer;
                "image/jxl" = imageViewer;
                "application/pdf" = pdfViewer;
                "x-scheme-handler/http" = browser;
                "x-scheme-handler/https" = browser;
                "x-scheme-handler/chrome" = browser;
                "text/html" = browser;
                "application/x-extension-htm" = browser;
                "application/x-extension-html" = browser;
                "application/x-extension-shtml" = browser;
                "application/xhtml+xml" = browser;
                "application/x-extension-xhtml" = browser;
                "application/x-extension-xht" = browser;
              };
            in
            {
              enable = true;
              defaultApplications = associations;
              associations.added = associations;
            };
        };

        wayland.windowManager.hyprland = {
          enable = true;
          package = null;
          portalPackage = null;
          systemd.enable = false;
          xwayland.enable = true;

          plugins = [
            pkgs.split-monitor-workspaces
          ];

          settings = {
            env = [
              "XDG_CURRENT_DESKTOP,Hyprland"
              "XDG_SESSION_DESKTOP,Hyprland"
              "XDG_SESSION_TYPE,wayland"
            ];
            exec-once = [
              "uwsm finalize"
            ];
            ecosystem = {
              no_donation_nag = true;
            };
            misc = {
              disable_hyprland_logo = true;
              focus_on_activate = true;
              enable_swallow = true;
              swallow_regex = "^(kitty)$";
            };
            xwayland.force_zero_scaling = true;

            # Input
            input = {
              follow_mouse = 1;
              accel_profile = "flat";
              kb_layout = "us";
              numlock_by_default = true;
              touchpad = {
                disable_while_typing = true;
                natural_scroll = "no";
                tap-to-click = true;
              };
              sensitivity = 0;
              scroll_factor = 1.0;
              emulate_discrete_scroll = 1;
              repeat_delay = 275;
              repeat_rate = 35;
            };

            # Tiling (dwindle)
            dwindle = {
              pseudotile = true;
              preserve_split = true;
              special_scale_factor = 0.85;
              force_split = 2;
            };
            general.resize_on_border = true;

            # Animations
            animations = {
              enabled = "yes";
              bezier = [
                "myBezier, 0.05, 0.9, 0.1, 1.05"
                "linear, 0.0, 0.0, 1.0, 1.0"
                "wind, 0.05, 0.9, 0.1, 1.05"
                "winIn, 0.1, 1.1, 0.1, 1.1"
                "winOut, 0.3, -0.3, 0, 1"
                "slow, 0, 0.85, 0.3, 1"
                "overshot, 0.7, 0.6, 0.1, 1.1"
                "bounce, 1.1, 1.6, 0.1, 0.85"
                "sligshot, 1, -1, 0.15, 1.25"
                "nice, 0, 6.9, 0.5, -4.20"
              ];
              animation = [
                "windowsIn, 1, 2, slow, popin"
                "windowsOut, 1, 2, winOut, popin"
                "windowsMove, 1, 1, wind, slide"
                "border, 1, 1, linear"
                "fade, 1, 3, overshot"
                "workspaces, 1, 3, wind"
                "windows, 1, 3, bounce, popin"
              ];
            };

            # Split monitor workspaces plugin
            plugin.split-monitor-workspaces = {
              count = 5;
              keep_focused = false;
              enable_notifications = false;
              enable_persistent_workspaces = 1;
              enable_wrapping = false;
            };

            # Keybinds — mouse
            bindm = [
              "${PRIMARY}, mouse:272, movewindow"
            ];

            # Keybinds — lock (media keys)
            bindl = [
              ", xf86AudioLowerVolume, exec, ${wpctl} set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%- && ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ 0"
              ", xf86AudioRaiseVolume, exec, ${wpctl} set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ 0"
              ", xf86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
              ", XF86AudioPlay, exec, ${playerctlBin} play-pause"
              ", XF86AudioPause, exec, ${playerctlBin} play-pause"
              ", XF86AudioPrev, exec, ${playerctlBin} previous"
              ", XF86AudioNext, exec, ${playerctlBin} next"
              "${TERTIARY} ${SECONDARY}, N, exec, ${playerctlBin} next"
              "${TERTIARY} ${SECONDARY}, P, exec, ${playerctlBin} previous"
              "${TERTIARY} ${SECONDARY}, SPACE, exec, ${playerctlBin} play-pause"
            ];

            # Keybinds — repeat (resize)
            binde = [
              "${PRIMARY} ${SECONDARY}, left, resizeactive,-50 0"
              "${PRIMARY} ${SECONDARY}, right, resizeactive,50 0"
              "${PRIMARY} ${SECONDARY}, up, resizeactive,0 -50"
              "${PRIMARY} ${SECONDARY}, down, resizeactive,0 50"
            ];

            # Keybinds — lock + repeat (brightness)
            bindle = [
              ", xf86MonBrightnessDown, exec, ${brightnessctlBin} set 5%- -q"
              ", xf86MonBrightnessUp, exec, ${brightnessctlBin} set 5%+ -q"
            ];

            # Keybinds — main
            bind =
              [
                "ALT, Tab, cyclenext, next"
                "SUPER, Tab, focusmonitor, +1"
                "ALT SHIFT, Tab, cyclenext, prev"
                "SUPER SHIFT, Tab, focusmonitor, -1"

                # Apps
                "${PRIMARY}, Return, exec, ${term}"
                "${PRIMARY} ${SECONDARY}, Return, exec, ${term} -e ${editor}"
                "${PRIMARY}, Space, exec, ${wofi}/bin/wofi --allow-images --show drun"
                "${PRIMARY}, E, exec, ${term} -e yazi"
                "${PRIMARY} ${SECONDARY}, H, exec, ${term} -e btop"
                "${PRIMARY} ${SECONDARY}, N, exec, ${term} -e nvtop"
                "${PRIMARY} ${SECONDARY}, S, exec, ${term} -o term=xterm-kitty --class spotify_player -e spotify_player"
                "${PRIMARY} ${SECONDARY}, B, exec, ${prefix} firefox --new-window"

                # Screenshots
                ", Print, exec, ${hyprshotBin} -m region --clipboard-only --freeze"
                "ALT, Print, exec, ${hyprshotBin} -m window --clipboard-only --freeze"
                "${SECONDARY}, Print, exec, ${hyprshotBin} -m output --clipboard-only --freeze"
                ", xf86Cut, exec, ${hyprshotBin} -m region --raw --freeze | ${swappyBin} -f -"
                "${PRIMARY}, Print, exec, ${wl-paste} | ${swappyBin} -f -"

                # Window management
                "${PRIMARY}, Q, killactive"
                "${PRIMARY}, F, fullscreen"
                "${PRIMARY} ${SECONDARY}, F, togglefloating"
                "${PRIMARY}, P, pseudo"
                "${PRIMARY}, S, togglesplit"
                "${PRIMARY} ${SECONDARY}, L, exec, ${loginctl}  lock-session"
                "${PRIMARY} ${SECONDARY}, C, exec, ${uwsm} stop"

                # Move focus
                "${PRIMARY}, h, movefocus, l"
                "${PRIMARY}, j, movefocus, d"
                "${PRIMARY}, k, movefocus, u"
                "${PRIMARY}, l, movefocus, r"
                "${PRIMARY}, left, movefocus, l"
                "${PRIMARY}, down, movefocus, d"
                "${PRIMARY}, up, movefocus, u"
                "${PRIMARY}, right, movefocus, r"

                # Move windows
                "${PRIMARY} ${TERTIARY}, h, movewindow, l"
                "${PRIMARY} ${TERTIARY}, j, movewindow, d"
                "${PRIMARY} ${TERTIARY}, k, movewindow, u"
                "${PRIMARY} ${TERTIARY}, l, movewindow, r"
                "${PRIMARY} ${TERTIARY}, left, movewindow, l"
                "${PRIMARY} ${TERTIARY}, down, movewindow, d"
                "${PRIMARY} ${TERTIARY}, up, movewindow, u"
                "${PRIMARY} ${TERTIARY}, right, movewindow, r"

                # Split-monitor workspaces
                "${PRIMARY}, page_up, split-workspace, m-1"
                "${PRIMARY}, page_down, split-workspace, m+1"
                "${PRIMARY}, bracketleft, split-workspace, -1"
                "${PRIMARY}, bracketright, split-workspace, +1"
                "${PRIMARY}, mouse_up, split-workspace, m+1"
                "${PRIMARY}, mouse_down, split-workspace, m-1"
                "${PRIMARY} ${SECONDARY}, U, movetoworkspace, special"
                "${PRIMARY}, U, togglespecialworkspace,"
                "${PRIMARY} ${TERTIARY}, page_up, split-movetoworkspace, -1"
                "${PRIMARY} ${TERTIARY}, page_down, split-movetoworkspace, +1"
                "${PRIMARY} ${SECONDARY}, page_up, split-movetoworkspacesilent, -1"
                "${PRIMARY} ${SECONDARY}, page_down, split-movetoworkspacesilent, +1"
                "${PRIMARY} ${TERTIARY}, left, split-changemonitor, prev"
                "${PRIMARY} ${TERTIARY}, right, split-changemonitor, next"
              ]
              ++ (builtins.concatLists (
                builtins.genList (
                  x:
                  let
                    ws = toString (x + 1);
                  in
                  [
                    "${PRIMARY}, ${ws}, split-workspace, ${toString (x + 1)}"
                    "${PRIMARY} ${TERTIARY}, ${ws}, split-movetoworkspace, ${toString (x + 1)}"
                    "${PRIMARY} ${SECONDARY}, ${ws}, split-movetoworkspacesilent, ${toString (x + 1)}"
                  ]
                ) 5
              ));
          };
        };
      };
  };
}

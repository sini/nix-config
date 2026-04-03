{ den, lib, ... }:
{
  # Note: hyprland requires xdg-portal and uwsm aspects to be included by the host
  den.aspects.hyprland = {
    includes = lib.attrValues den.aspects.hyprland._;

    _ = {
      nixos = den.lib.perHost {
        nixos =
          {
            inputs,
            pkgs,
            lib,
            ...
          }:
          {
            environment.systemPackages = with pkgs; [
              xwayland-satellite
              wlogout
              swaylock
            ];

            # Enable cachix
            nix.settings = {
              substituters = [ "https://hyprland.cachix.org" ];
              trusted-substituters = [ "https://hyprland.cachix.org" ];
              trusted-public-keys = [
                "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
              ];
            };

            environment.sessionVariables = {
              NIXOS_OZONE_WL = "1"; # wayland for electron apps
              # NOTE: https://github.com/NixOS/nixpkgs/issues/353990
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
                packages = with pkgs; [
                  gcr
                  gnome-settings-daemon
                ];
              };

              gnome.gnome-keyring.enable = true;
              gnome.sushi.enable = true;
              devmon.enable = true;
              gvfs.enable = true;
              udisks2.enable = true;
            };
          };
      };

      home = den.lib.perUser {
        homeManager =
          {
            config,
            inputs,
            lib,
            pkgs,
            ...
          }:
          {
            imports = [
              inputs.hyprland.homeManagerModules.default
            ];

            home.packages = with pkgs; [
              hyprpicker
              hyprcursor
              libnotify
              networkmanagerapplet
              blueman
              pwvucontrol
              snapshot
            ];

            xdg.configFile."uwsm/env".source =
              "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

            programs = {
              wofi.enable = true;
              rofi = {
                enable = true;
              };
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

            services = {
              hyprpaper = {
                enable = true;
                settings = {
                  ipc = "on";
                  splash = false;
                };
              };
            };

            wayland.windowManager.hyprland = {
              enable = true;
              package = null;
              portalPackage = null;

              # Disabled because it conflicts with uwsm
              # https://wiki.hypr.land/Useful-Utilities/Systemd-start/
              systemd.enable = false;

              xwayland.enable = true;

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
                };
                xwayland.force_zero_scaling = true;
              };
            };
          };
      };

      # Animations sub-aspect
      animations = den.lib.perUser {
        homeManager = {
          wayland.windowManager.hyprland.settings.animations = {
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
        };
      };

      # Input sub-aspect
      input = den.lib.perUser {
        homeManager = {
          wayland.windowManager.hyprland.settings = {
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
          };
        };
      };

      # Keybinds sub-aspect
      keybinds = den.lib.perUser {
        homeManager =
          {
            pkgs,
            osConfig,
            ...
          }:
          let
            uwsm = "${pkgs.uwsm}/bin/uwsm";
            prefix = if osConfig.programs.hyprland.withUWSM then "${uwsm} app --" else "";

            term = "${prefix} kitty";
            editor = "nvim";

            brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
            hyprshot = "${pkgs.hyprshot}/bin/hyprshot";
            loginctl = "${pkgs.elogind}/bin/loginctl";
            playerctl = "${pkgs.playerctl}/bin/playerctl";
            swappy = "${pkgs.swappy}/bin/swappy";
            wl-paste = "${pkgs.wl-clipboard}/bin/wl-paste";
            wpctl = "${pkgs.wireplumber}/bin/wpctl";
            PRIMARY = "SUPER";
            SECONDARY = "SHIFT";
            TERTIARY = "CTRL";
          in
          {
            wayland.windowManager.hyprland.settings = {
              # mouse
              bindm = [
                "${PRIMARY}, mouse:272, movewindow"
              ];

              # lock
              bindl = [
                ", xf86AudioLowerVolume, exec, ${wpctl} set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%- && ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ 0"
                ", xf86AudioRaiseVolume, exec, ${wpctl} set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ 0"
                ", xf86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
                ", XF86AudioPlay, exec, ${playerctl} play-pause"
                ", XF86AudioPause, exec, ${playerctl} play-pause"
                ", XF86AudioPrev, exec, ${playerctl} previous"
                ", XF86AudioNext, exec, ${playerctl} next"
                "${TERTIARY} ${SECONDARY}, N, exec, ${playerctl} next"
                "${TERTIARY} ${SECONDARY}, P, exec, ${playerctl} previous"
                "${TERTIARY} ${SECONDARY}, SPACE, exec, ${playerctl} play-pause"
              ];

              # repeat
              binde = [
                "${PRIMARY} ${SECONDARY}, left, resizeactive,-50 0"
                "${PRIMARY} ${SECONDARY}, right, resizeactive,50 0"
                "${PRIMARY} ${SECONDARY}, up, resizeactive,0 -50"
                "${PRIMARY} ${SECONDARY}, down, resizeactive,0 50"
              ];

              # lock + repeat
              bindle = [
                ", xf86MonBrightnessDown, exec, ${brightnessctl} set 5%- -q"
                ", xf86MonBrightnessUp, exec, ${brightnessctl} set 5%+ -q"
              ];

              bind = [
                "ALT, Tab, cyclenext, next"
                "SUPER, Tab, focusmonitor, +1"
                "ALT SHIFT, Tab, cyclenext, prev"
                "SUPER SHIFT, Tab, focusmonitor, -1"

                # apps
                "${PRIMARY}, Return, exec, ${term}"
                "${PRIMARY} ${SECONDARY}, Return, exec, ${term} -e ${editor}"
                "${PRIMARY}, Space, exec, ${pkgs.wofi}/bin/wofi --allow-images --show drun"
                "${PRIMARY}, E, exec, ${term} -e yazi"
                "${PRIMARY} ${SECONDARY}, H, exec, ${term} -e btop"
                "${PRIMARY} ${SECONDARY}, N, exec, ${term} -e nvtop"
                "${PRIMARY} ${SECONDARY}, S, exec, ${term} -o term=xterm-kitty --class spotify_player -e spotify_player"
                "${PRIMARY} ${SECONDARY}, B, exec, ${prefix} firefox --new-window"

                # screenshots
                ", Print, exec, ${hyprshot} -m region --clipboard-only --freeze"
                "ALT, Print, exec, ${hyprshot} -m window --clipboard-only --freeze"
                "${SECONDARY}, Print, exec, ${hyprshot} -m output --clipboard-only --freeze"
                ", xf86Cut, exec, ${hyprshot} -m region --raw --freeze | ${swappy} -f -"
                "${PRIMARY}, Print, exec, ${wl-paste} | ${swappy} -f -"

                # main
                "${PRIMARY}, Q, killactive"
                "${PRIMARY}, F, fullscreen"
                "${PRIMARY} ${SECONDARY}, F, togglefloating"
                "${PRIMARY}, P, pseudo"
                "${PRIMARY}, S, togglesplit"
                "${PRIMARY} ${SECONDARY}, L, exec, ${loginctl}  lock-session"
                "${PRIMARY} ${SECONDARY}, C, exec, ${uwsm} stop"

                # move focus
                "${PRIMARY}, h, movefocus, l"
                "${PRIMARY}, j, movefocus, d"
                "${PRIMARY}, k, movefocus, u"
                "${PRIMARY}, l, movefocus, r"
                "${PRIMARY}, left, movefocus, l"
                "${PRIMARY}, down, movefocus, d"
                "${PRIMARY}, up, movefocus, u"
                "${PRIMARY}, right, movefocus, r"

                # move windows
                "${PRIMARY} ${TERTIARY}, h, movewindow, l"
                "${PRIMARY} ${TERTIARY}, j, movewindow, d"
                "${PRIMARY} ${TERTIARY}, k, movewindow, u"
                "${PRIMARY} ${TERTIARY}, l, movewindow, r"
                "${PRIMARY} ${TERTIARY}, left, movewindow, l"
                "${PRIMARY} ${TERTIARY}, down, movewindow, d"
                "${PRIMARY} ${TERTIARY}, up, movewindow, u"
                "${PRIMARY} ${TERTIARY}, right, movewindow, r"
              ];
            };
          };
      };

      # Tiling sub-aspect
      tiling = den.lib.perUser {
        homeManager = {
          wayland.windowManager.hyprland.settings = {
            dwindle = {
              pseudotile = true;
              preserve_split = true;
              special_scale_factor = 0.85;
              force_split = 2;
            };

            general.resize_on_border = true;

            misc = {
              focus_on_activate = true;
              enable_swallow = true;
              swallow_regex = "^(kitty)$";
            };
          };
        };
      };

      # Window rules sub-aspect (currently commented out, kept as placeholder)
      window-rules = den.lib.perUser {
        homeManager = {
          wayland.windowManager.hyprland.settings = { };
        };
      };

      # XDG mime associations sub-aspect
      xdg-mime = den.lib.perUser {
        homeManager =
          let
            editor = [ "nvim.desktop" ];
            browser = [ "firefox.desktop" ];
            imageViewer = [ "org.gnome.Loupe.desktop" ];
            pdfViewer = [ "org.pwmt.zathura.desktop" ];
            associations = {
              "text/x-dbus-service" = editor;
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
            xdg = {
              configFile."mimeapps.list".force = true;
              mimeApps = {
                enable = true;
                defaultApplications = associations;
                associations.added = associations;
              };
            };
          };
      };
    };
  };
}

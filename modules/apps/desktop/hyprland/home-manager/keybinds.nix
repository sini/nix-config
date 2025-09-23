{
  flake.modules.homeManager.hyprland =
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
        plugin = {
          split-monitor-workspaces = {
            count = 10;
            keep_focused = 0;
            enable_notifications = 0;
          };
          hyprexo = {
            columns = 3;
            gap_size = 5;
            bg_col = "rgb(000000)";
            workspace_method = [
              "center"
              "current"
            ]; # [center/first] [workspace] e.g. first 1 or center m+1

            enable_gesture = true; # laptop touchpad
            gesture_fingers = 3; # 3 or 4
            gesture_distance = 300; # how far is the "max"
            gesture_positive = true; # positive = swipe down. Negative = swipe up.
          };
        };

        # mouse
        bindm = [
          "${PRIMARY}, mouse:272, movewindow" # move floating windows with ${PRIMARY}+LMK
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
          # resize windows
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
          #
          "ALT, Tab, cyclenext, next"
          "SUPER, Tab, focusmonitor, +1"
          "ALT SHIFT, Tab, cyclenext, prev"
          "SUPER SHIFT, Tab, focusmonitor, -1"
          #"CTRL ALT, TAB, overview:toggle, toggle, all"
          # apps
          "${PRIMARY}, Return, exec, ${term}"
          "${PRIMARY} ${SECONDARY}, Return, exec, ${term} -e ${editor}"
          "${PRIMARY}, Space, exec, ${pkgs.wofi}/bin/wofi --allow-images --show drun"
          "${PRIMARY}, E, exec, ${term} -e yazi"
          "${PRIMARY} ${SECONDARY}, H, exec, ${term} -e btop"
          "${PRIMARY} ${SECONDARY}, N, exec, ${term} -e nvtop"
          "${PRIMARY} ${SECONDARY}, S, exec, ${term} -o term=xterm-kitty --class spotify_player -e spotify_player"
          "${PRIMARY} ${SECONDARY}, B, exec, ${prefix} firefox --new-window"

          # Make screenshots!
          ", Print, exec, ${hyprshot} -m region --clipboard-only --freeze"
          "ALT, Print, exec, ${hyprshot} -m window --clipboard-only --freeze"
          "${SECONDARY}, Print, exec, ${hyprshot} -m output --clipboard-only --freeze"
          ", xf86Cut, exec, ${hyprshot} -m region --raw --freeze | ${swappy} -f -" # region -> edit
          "${PRIMARY}, Print, exec, ${wl-paste} | ${swappy} -f -" # clipboard -> edit

          # Record screen!
          # wf-recorder
          # wf-recorder -g "$(slurp)"
          # wf-recorder --audio
          # wf-recorder -f "name.mp4"

          # main
          "${PRIMARY}, Q, killactive" # or closewindow?
          "${PRIMARY}, F, fullscreen"
          "${PRIMARY} ${SECONDARY}, F, togglefloating"
          "${PRIMARY}, P, pseudo" # dwindle layout
          "${PRIMARY}, S, togglesplit" # dwindle layout
          "${PRIMARY} ${SECONDARY}, L, exec, ${loginctl}  lock-session"
          "${PRIMARY} ${SECONDARY}, C, exec, ${uwsm} stop"

          # group
          # "${PRIMARY}, G, togglegroup"
          # "ALT, tab, changegroupactive"
          # "${PRIMARY}, tab, changegroupactive"

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

          # workspaces
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

          # Move active window to other monitor with mainMod + TERTIARY + arrow keys
          "${PRIMARY} ${TERTIARY}, left, split-changemonitor, prev"
          "${PRIMARY} ${TERTIARY}, right, split-changemonitor, next"

          #"${PRIMARY}, grave, hyprexpo:expo, toggle"

          "${PRIMARY}, z, easymotion, action:hyprctl dispatch focuswindow address:{}"
          # 1..10 workspaces
        ]
        ++ (builtins.concatLists (
          builtins.genList (
            x:
            let
              ws =
                let
                  c = builtins.div (x + 1) 10;
                in
                builtins.toString (x + 1 - (c * 10));
            in
            [
              "${PRIMARY}, ${ws}, split-workspace, ${toString (x + 1)}"
              "${PRIMARY} ${TERTIARY}, ${ws}, split-movetoworkspace, ${toString (x + 1)}"
              "${PRIMARY} ${SECONDARY}, ${ws}, split-movetoworkspacesilent, ${toString (x + 1)}"
            ]
          ) 10
        ));

      };
    };
}

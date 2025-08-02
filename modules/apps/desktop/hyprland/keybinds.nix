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

    in
    {
      wayland.windowManager.hyprland.settings = {
        plugin = {
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
          "SUPER, mouse:272, movewindow" # move floating windows with SUPER+LMK
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
          "CTRL SHIFT, N, exec, ${playerctl} next"
          "CTRL SHIFT, P, exec, ${playerctl} previous"
          "CTRL SHIFT, SPACE, exec, ${playerctl} play-pause"
        ];

        # repeat
        binde = [
          # resize windows
          "SUPER SHIFT, left, resizeactive,-50 0"
          "SUPER SHIFT, right, resizeactive,50 0"
          "SUPER SHIFT, up, resizeactive,0 -50"
          "SUPER SHIFT, down, resizeactive,0 50"
        ];

        # lock + repeat
        bindle = [
          ", xf86MonBrightnessDown, exec, ${brightnessctl} set 5%- -q"
          ", xf86MonBrightnessUp, exec, ${brightnessctl} set 5%+ -q"
        ];

        bind = [
          # apps
          "SUPER, Return, exec, ${term}"
          "SUPER SHIFT, Return, exec, ${term} -e ${editor}"
          "SUPER, E, exec, ${term} -e yazi"
          "SUPER SHIFT, H, exec, ${term} -e btop"
          "SUPER SHIFT, N, exec, ${term} -e nvtop"
          "SUPER SHIFT, S, exec, ${term} -o term=xterm-kitty --class spotify_player -e spotify_player"
          "SUPER SHIFT, B, exec, ${prefix} firefox --new-window"

          # Make screenshots!
          ", Print, exec, ${hyprshot} -m region --clipboard-only --freeze"
          "ALT, Print, exec, ${hyprshot} -m window --clipboard-only --freeze"
          "SHIFT, Print, exec, ${hyprshot} -m output --clipboard-only --freeze"
          ", xf86Cut, exec, ${hyprshot} -m region --raw --freeze | ${swappy} -f -" # region -> edit
          "SUPER, Print, exec, ${wl-paste} | ${swappy} -f -" # clipboard -> edit

          # Record screen!
          # wf-recorder
          # wf-recorder -g "$(slurp)"
          # wf-recorder --audio
          # wf-recorder -f "name.mp4"

          # main
          "SUPER, Q, killactive" # or closewindow?
          "SUPER, F, fullscreen"
          "SUPER SHIFT, F, togglefloating"
          "SUPER, P, pseudo" # dwindle layout
          "SUPER, S, togglesplit" # dwindle layout
          "SUPER SHIFT, L, exec, ${loginctl}  lock-session"
          "SUPER SHIFT, C, exec, ${uwsm} stop"

          # group
          # "SUPER, G, togglegroup"
          # "ALT, tab, changegroupactive"
          # "SUPER, tab, changegroupactive"

          # move focus
          "SUPER, h, movefocus, l"
          "SUPER, j, movefocus, d"
          "SUPER, k, movefocus, u"
          "SUPER, l, movefocus, r"
          "SUPER, left, movefocus, l"
          "SUPER, down, movefocus, d"
          "SUPER, up, movefocus, u"
          "SUPER, right, movefocus, r"

          # move windows
          "SUPER CTRL, h, movewindow, l"
          "SUPER CTRL, j, movewindow, d"
          "SUPER CTRL, k, movewindow, u"
          "SUPER CTRL, l, movewindow, r"
          "SUPER CTRL, left, movewindow, l"
          "SUPER CTRL, down, movewindow, d"
          "SUPER CTRL, up, movewindow, u"
          "SUPER CTRL, right, movewindow, r"

          # workspaces
          "SUPER, page_up, split-workspace, m-1"
          "SUPER, page_down, split-workspace, m+1"
          "SUPER, bracketleft, split-workspace, -1"
          "SUPER, bracketright, split-workspace, +1"
          "SUPER, mouse_up, split-workspace, m+1"
          "SUPER, mouse_down, split-workspace, m-1"
          "SUPER SHIFT, U, movetoworkspace, special"
          "SUPER, U, togglespecialworkspace,"
          "SUPER CTRL, page_up, split-movetoworkspace, -1"
          "SUPER CTRL, page_down, split-movetoworkspace, +1"
          "SUPER SHIFT, page_up, split-movetoworkspacesilent, -1"
          "SUPER SHIFT, page_down, split-movetoworkspacesilent, +1"
          # "SUPER CTRL, bracketleft, movetoworkspace, -1"
          # "SUPER CTRL, bracketright, movetoworkspace, +1"
          # "SUPER SHIFT, bracketleft, movetoworkspacesilent, -1"
          # "SUPER SHIFT, bracketright, movetoworkspacesilent, +1"
          "SUPER SHIFT, bracketleft,  movecurrentworkspacetomonitor, -1"
          "SUPER SHIFT, bracketleft, focusmonitor, -1"
          "SUPER SHIFT, bracketright,  movecurrentworkspacetomonitor, +1"
          "SUPER SHIFT, bracketright, focusmonitor, +1"

          "SUPER, grave, hyprexpo:expo, toggle"
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
              "SUPER, ${ws}, split-workspace, ${toString (x + 1)}"
              "SUPER CTRL, ${ws}, split-movetoworkspace, ${toString (x + 1)}"
              "SUPER SHIFT, ${ws}, split-movetoworkspacesilent, ${toString (x + 1)}"
            ]
          ) 10
        ));

      };
    };
}

{
  flake.features.hyprland.home =
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
          # GDM Session Switch:
          # gdbus call --system \
          # --dest org.gnome.DisplayManager \
          # --object-path /org/gnome/DisplayManager/LocalDisplayFactory \
          # --method org.gnome.DisplayManager.LocalDisplayFactory.CreateTransientDisplay
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
        ];
      };
    };
}

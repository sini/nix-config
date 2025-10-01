{
  flake.aspects.kitty.home =
    { config, ... }:
    {
      programs.kitty = {
        enable = true;

        shellIntegration = {
          enableBashIntegration = config.programs.bash.enable;
          enableFishIntegration = config.programs.fish.enable;
          enableZshIntegration = config.programs.zsh.enable;
        };

        # https://sw.kovidgoyal.net/kitty/conf/
        settings = {

          # gotta go fast!
          repaint_delay = 8; # 150 FPS
          input_delay = 0; # Remove artificial input delay
          sync_to_monitor = "no"; # turn off vsync

          # Window
          # background_opacity = "0.8";
          # TODO: For tiling WM's
          # hide_window_decorations = "yes";
          #hide_window_decorations = if pkgs.stdenv.isDarwin then "titlebar-only" else "yes";
          confirm_os_window_close = "2";

          enable_audio_bell = "no";
          copy_on_select = "yes";
          cursor_trail = 3;

          scrollback_lines = "20000";
        };

        keybindings = {
          "ctrl+backspace" = "send_text all \\x17";
          "ctrl+delete" = "send_text all \\ed";
          "ctrl+v" = "paste_from_clipboard";
          "ctrl+shift+left" = "none"; # conflicts with nvim KBs
          "ctrl+shift+right" = "none";
        };
      };
    };
}

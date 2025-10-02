{
  flake.features.mangohud.home =
    { pkgs, ... }:

    {
      programs.mangohud = {
        enable = true;
        enableSessionWide = true;
      };

      stylix.targets.mangohud.enable = false; # Overrides the config file

      # can't use the `programs.mangohud.settings` option as it sorts the keys, which changes the rendering order
      # Colors are taken from https://github.com/catppuccin/mangohud/blob/main/themes/mocha/MangoHud.conf
      xdg.configFile."MangoHud/MangoHud.conf".text = # conf
        ''
          # Hidden by default
          no_display

          # Text
          font_size=14
          font_file=${pkgs.aporetic}/share/fonts/truetype/aporetic-sans-mono-normalregularupright.ttf
          text_color=CDD6F4
          text_outline_color=313244

          # Layout
          horizontal
          hud_compact
          position=top-left
          background_alpha=0.8
          background_color=1E1E2E
          round_corners=10

          # Bindings
          toggle_hud=Shift_R+F12
          toggle_preset=Shift_R+F10

          # Clock
          time
          time_no_label

          # GPU
          gpu_stats
          gpu_temp
          gpu_load_change
          gpu_load_value=50,90
          gpu_load_color=CDD6F4,FAB387,F38BA8
          gpu_text=GPU
          gpu_color=A6E3A1

          # CPU
          cpu_stats
          cpu_temp
          cpu_load_change
          cpu_load_value=50,90
          cpu_load_color=CDD6F4,FAB387,F38BA8
          cpu_color=89B4FA
          cpu_text=CPU
          core_load_change

          ## RAM ##
          ram
          ram_color=F5C2E7

          # FPS
          fps
          fps_color_change=F38BA8,F9E2AF,A6E3A1

          # Graph
          frame_timing
          frametime_color=A6E3A1
        '';
    };
}

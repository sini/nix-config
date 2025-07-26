{
  flake.modules.homeManager.misc-tools =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        atool
        bottom # btm
        du-dust
        dua
        dysk
        procs
        mprocs
        ncdu
        wget # not a file util....
        dig # not a file util....
        fd
        file
        jq
        ripgrep
        ripgrep-all
        unzip
        tokei
      ];
      # Enable easyeffects audio processing
      services.easyeffects.enable = true;

      programs = {
        bottom.enable = true;
        htop.enable = true;
        fd = {
          enable = true;
          hidden = true;
          ignores = [
            ".Trash"
            ".git"
            "**/node_modules"
            "**/target"
          ];
          extraOptions = [ "--no-ignore-vcs" ];
        };
        fzf = {
          enable = true;
          enableBashIntegration = true;
          enableFishIntegration = true;
          enableZshIntegration = true;
        };
        jq.enable = true;
        lazysql.enable = true;
        navi = {
          enable = true;
          enableBashIntegration = true;
          enableZshIntegration = true;
        };
        nix-index = {
          enable = true;
          enableBashIntegration = true;
          enableFishIntegration = true;
          enableZshIntegration = true;
        };
        #rclone.enable = true; # rclone is a cloud storage manager
        ripgrep = {
          enable = true;
          arguments = [
            # "--color=always" # conflict with telescope.nvim
            "--smart-case"
            "--no-line-number"
            "--hidden"
            "--glob=!.git/*"
            "--max-columns=150"
            "--max-columns-preview"
          ];
        };
        skim.enable = true;
        tealdeer = {
          enable = true;
          settings.updates.auto_update = true;
        };
        television = {
          enable = true;
          enableBashIntegration = true;
          enableZshIntegration = true;
          settings = {
            tick_rate = 50;
            ui = {
              use_nerd_font_icons = true;
              ui_scale = 120;
              show_preview_panel = true;
            };
            keybindings = {
              quit = [
                "esc"
                "ctrl-c"
              ];
            };
          };
        };
        zoxide = {
          enable = true;
          enableBashIntegration = true;
          enableFishIntegration = true;
          enableNushellIntegration = true;
          enableZshIntegration = true;
          options = [
            "--cmd"
            "cd"
          ];
        };
      };
    };
}

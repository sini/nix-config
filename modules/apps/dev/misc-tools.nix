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
        tlrc
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

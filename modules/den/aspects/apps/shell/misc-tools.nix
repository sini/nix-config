_: {
  den.aspects.apps.misc-tools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          # archive tools
          pkgs.atool
          pkgs.unzip
          pkgs.unrar
          pkgs.cabextract
          pkgs.p7zip
          pkgs.zip
          pkgs.xz

          # data tools
          pkgs.file
          pkgs.wget
          pkgs.dig
          pkgs.yq
          pkgs.tokei

          # disk tools
          pkgs.dust
          pkgs.dua
          pkgs.dysk
          pkgs.ncdu

          # process tools
          pkgs.procs
          pkgs.mprocs
        ];

        programs = {
          # search tools
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
          ripgrep = {
            enable = true;
            arguments = [
              "--smart-case"
              "--no-line-number"
              "--hidden"
              "--glob=!.git/*"
              "--max-columns=150"
              "--max-columns-preview"
            ];
          };
          skim.enable = true;

          # data tools
          jq.enable = true;
          navi = {
            enable = true;
            enableBashIntegration = true;
            enableZshIntegration = true;
          };
          tealdeer = {
            enable = true;
            settings.updates.auto_update = true;
          };
          lazysql.enable = true;

          # process tools
          htop.enable = true;
        };
      };
  };
}

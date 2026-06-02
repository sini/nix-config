_: {
  den.aspects.apps.shell.data = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.file
          pkgs.wget
          pkgs.dig
          pkgs.yq
          pkgs.tokei
        ];

        programs = {
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
        };
      };
  };
}

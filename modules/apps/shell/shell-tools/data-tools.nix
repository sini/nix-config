{
  features.data-tools.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        file
        wget
        dig
        yq
        tokei
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
}

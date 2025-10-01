{
  flake.aspects.xdg.home =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        xdg-utils
      ];

      xdg = {
        enable = true;
        userDirs = {
          enable = true;
          desktop = "$HOME/desktop";
          documents = "$HOME/documents";
          download = "$HOME/downloads";
          music = "$HOME/music";
          pictures = "$HOME/pictures";
          publicShare = "$HOME/public";
          templates = "$HOME/documents/templates";
          videos = "$HOME/videos";
        };
      };
    };
}

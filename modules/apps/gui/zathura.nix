{
  flake.modules.homeManager.zathura = {
    programs.zathura = {
      enable = true;
      # custom settings
      options = {
        selection-clipboard = "clipboard";
      };
    };
  };
}

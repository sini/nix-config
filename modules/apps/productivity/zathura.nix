{
  flake.modules.homeManager.zathura = {
    programs.zathura = {
      enable = true;
      # custom settings
      options = {
        guioptions = "v";
        adjust-open = "width";
        statusbar-basename = true;
        render-loading = false;
        scroll-step = 120;
        selection-clipboard = "clipboard";
      };
    };
  };
}

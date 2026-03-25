{
  features.lazygit.home = _: {
    programs.lazygit = {
      enable = true;
      settings = {
        gui = {
          nerdFontsVersion = "3";
        };
        git = {
          overrideGpg = true;
          log.order = "default";
          parseEmoji = true;
          commit.signOff = true;
          fetchAll = false;
        };
      };
    };
    home.shellAliases = {
      lg = "lazygit";
    };
  };
}

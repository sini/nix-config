{ den, ... }:
{
  den.aspects.lazygit = den.lib.perUser {
    homeManager = {
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
  };
}

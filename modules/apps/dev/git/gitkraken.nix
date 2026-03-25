{
  features.gitkraken.home =
    {
      inputs,
      pkgs,
      user,
      ...
    }:
    {
      imports = [
        inputs.nixkraken.homeManagerModules.nixkraken
      ];

      programs.nixkraken = {
        enable = true;
        acceptEULA = true;
        skipTutorial = true;
        notifications = {
          feature = false;
          help = false;
          marketing = false;
        };

        graph = {
          compact = true;
          showAuthor = true;
          showDatetime = true;
          showMessage = true;
          showRefs = false;
          showSHA = false;
          showGraph = true;
        };

        tools.terminal = {
          package = pkgs.alacritty;
        };

        ui = {
          extraThemes = [ "${pkgs.local.catppuccin-gitkraken}/catppuccin-mocha.jsonc" ];
          theme = "catppuccin-mocha.jsonc";

          editor = {
            tabSize = 2;
            wrap = true;
          };
        };

        user = {
          inherit (user.identity) email;
          name = user.identity.displayName;
        };

        gpg = {
          package = pkgs.gnupg;
          signCommits = user.identity.gpgKey or null != null;
          signTags = user.identity.gpgKey or null != null;
          signingKey = user.identity.gpgKey or null;
        };
      };

      home.persistence."/persist".directories = [
        ".gitkraken/"
        ".gk/"
        ".config/GitKraken/"
      ];
    };
}

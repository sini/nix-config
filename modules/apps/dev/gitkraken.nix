{
  flake.features.gitkraken.home =
    {
      inputs,
      config,
      pkgs,
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
          email = config.programs.git.defaultIdentity.email;
          name = config.programs.git.defaultIdentity.fullName;
        };

        gpg = {
          signCommits = true;
          signTags = true;
          signingKey = config.programs.git.defaultIdentity.signingKey;
        };
      };
    };

}

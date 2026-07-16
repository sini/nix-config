{
  den.aspects.apps.dev.mux.sesh = {
    homeManager = {
      programs.sesh = {
        enable = true;
        enableTmuxIntegration = false;
        settings = {
          blacklist = [ "scratch" ];
          session = [
            {
              name = "home";
              path = "~/";
              # startup_command = "ls";
            }
          ];
          default_session = {
            preview_command = "eza --oneline --all --git --icons --color=always {}";
          };
        };
      };
    };
  };
}

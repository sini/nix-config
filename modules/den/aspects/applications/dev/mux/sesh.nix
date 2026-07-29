{
  den.aspects.applications.dev.mux.sesh = {
    homeManager = {
      programs.sesh = {
        enable = true;
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

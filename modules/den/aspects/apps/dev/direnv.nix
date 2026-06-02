_: {
  den.aspects.apps.dev.direnv = {
    os = {
      nix.settings = {
        keep-outputs = true;
        keep-derivations = true;
      };
    };

    homeManager =
      { config, ... }:
      {
        programs = {
          direnv = {
            enable = true;
            nix-direnv.enable = true;
            config.global.warn_timeout = 0;
            enableBashIntegration = true;
            enableZshIntegration = config.programs.zsh.enable;
            enableNushellIntegration = config.programs.nushell.enable;
          };

          git.ignores = [
            ".envrc"
            ".direnv"
          ];
        };
      };
  };
}

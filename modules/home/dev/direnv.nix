{
  flake.modules.homeManager.direnv =
    { config, ... }:
    {
      programs = {
        direnv = {
          enable = true;
          enableZshIntegration = config.programs.zsh.enable;
          enableNushellIntegration = config.programs.nushell.enable;
          nix-direnv.enable = true;
          config.global.warn_timeout = 0;
        };

        git.ignores = [
          ".envrc"
          ".direnv"
        ];
      };
    };
}

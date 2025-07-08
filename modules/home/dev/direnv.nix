{
  flake.modules.homeManager.direnv =
    { config, ... }:
    {
      programs = {
        direnv = {
          enable = true;
          nix-direnv.enable = true;
          config.global.warn_timeout = 0;
          enableZshIntegration = config.programs.zsh.enable;
          enableNushellIntegration = config.programs.nushell.enable;
        };

        git.ignores = [
          ".envrc"
          ".direnv"
        ];
      };
    };
}

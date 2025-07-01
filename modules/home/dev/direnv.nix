{
  flake.modules.homeManager.direnv =
    { config, ... }:
    {
      programs.direnv = {
        enableZshIntegration = config.programs.zsh.enable;
        enableNushellIntegration = config.programs.nushell.enable;
        nix-direnv.enable = true;
        config.global.warn_timeout = 0;
      };

    };
}

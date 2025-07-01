{ config, ... }:
{
  flake.modules.nixos.home-ext = {
    home-manager.users.${config.flake.meta.user.username}.imports = [
      config.flake.modules.homeManager.ext
    ];
  };

  flake.modules.homeManager.ext =
    { config, ... }:
    {
      programs.direnv = {
        enableZshIntegration = config.programs.zsh.enable;
        enableNushellIntegration = config.programs.nushell.enable;
      };

    };
}

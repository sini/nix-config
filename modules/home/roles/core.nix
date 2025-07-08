{ config, ... }:
{
  flake.modules.homeManager.core = {
    home = {
      # TODO: Fix this to support nix-darwin
      username = config.flake.meta.user.username;
      homeDirectory = "/home/${config.flake.meta.user.username}";
    };
    programs.home-manager.enable = true;
  };

  flake.modules.nixos.home-core = {
    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        core
        starship
        zsh
      ];
  };
}

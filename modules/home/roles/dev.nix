{ config, ... }:
{
  flake.modules.nixos.home-dev = {
    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        bat
        direnv
        eza
        git
        gpg
        yazi
      ];
  };
}

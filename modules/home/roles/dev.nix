{ config, ... }:
{
  flake.modules.nixos.home-dev = {
    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        direnv
        eza
        file-tools
        git
        gpg
        yazi
      ];
  };
}

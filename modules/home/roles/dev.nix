{ config, ... }:
{
  flake.modules.nixos.home-dev = {
    home-manager.users.${config.flake.meta.user.username}.imports = [
      config.flake.modules.homeManager.direnv
      config.flake.modules.homeManager.git
      config.flake.modules.homeManager.gpg
    ];
  };
}

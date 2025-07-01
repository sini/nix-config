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
}

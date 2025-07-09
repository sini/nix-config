{ config, ... }:
{
  flake.modules.nixos.role_workstation = {
    imports = with config.flake.modules.nixos; [
      role_dev
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        alacritty
      ];
  };
}

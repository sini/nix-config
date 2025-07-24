{ config, ... }:
{
  flake.modules.nixos.role_gaming = {
    imports = with config.flake.modules.nixos; [
      steam
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        mangohud
      ];
  };
}

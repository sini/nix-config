{ config, ... }:
{
  flake.modules.nixos.role_dev = {
    imports = with config.flake.modules.nixos; [
      direnv
      vscode
      gpg
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        bat
        direnv
        eza
        misc-tools
        git
        gpg
        ssh
        yazi
        zellij
      ];
  };
}

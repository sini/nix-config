{ config, ... }:
{
  flake.modules.nixos.role_dev-gui = {
    imports = with config.flake.modules.nixos; [
      gpg
      vscode
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        gitkraken
        gpg
        wireshark
        kube-tools
        zellij
      ];
  };
}

{ config, ... }:
{
  flake.modules.nixos.role_dev = {
    imports = with config.flake.modules.nixos; [
      adb
      direnv
      #gpg
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        bat
        claude
        direnv
        eza
        misc-tools
        nvf
        git
        #gpg
        ssh
        yazi
        #zellij

        # Admin tools
        k9s
      ];
  };
}

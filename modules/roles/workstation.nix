{ config, ... }:
{
  flake.modules.nixos.role_workstation = {
    imports = with config.flake.modules.nixos; [
      # Hardware modules
      audio
      bluetooth
      coolercontrol
      # Additional roles
      role_dev
      role_media

      # Styles
      fonts
      stylix

      virtualization
      xwayland

      hyprland
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        alacritty
        discord
        kitty
        fonts
        firefox
        obs-studio
        obsidian # note-taking app
        zathura # PDF viewer

        #
        hyprland
      ];
  };
}

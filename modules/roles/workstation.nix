{ config, ... }:
{
  flake.modules.nixos.role_workstation = {
    imports = with config.flake.modules.nixos; [
      # Hardware modules
      audio
      bluetooth
      # Additional roles
      role_dev
      role_media

      # Styles
      fonts
      stylix
      # X server
      xwayland
    ];

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        alacritty
        kitty
        fonts
        firefox
        obs-studio
        obsidian # note-taking app
        zathura # PDF viewer
      ];
  };
}

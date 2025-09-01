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
      role_dev-gui
      role_media

      # Styles
      stylix
      fonts

      virtualization

      # Desktop GUI
      xserver
      xwayland
      #gdm
      xdg-portal
      #gnome
      greetd # Doesn't work with gnome's session lock stuff... use if we don't need gnome
      hyprland

    ];

    # Enable NetworkManager for managing network interfaces
    networking.networkmanager.enable = true;

    home-manager.users.${config.flake.meta.user.username}.imports =
      with config.flake.modules.homeManager; [
        alacritty
        audio
        discord
        gnome
        kitty
        fonts
        firefox
        obs-studio
        obsidian # note-taking app
        zathura # PDF viewer
        # TODO:  Broken for now....
        hyprland
      ];
  };
}

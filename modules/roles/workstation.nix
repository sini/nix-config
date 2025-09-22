{ config, ... }:
{
  flake.role.workstation = {
    imports = with config.flake.modules.nixos; [
      # Hardware modules
      audio
      bluetooth
      coolercontrol

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

{
  flake.role.workstation = {
    nixosModules = [
      # Hardware modules
      "audio"
      "bluetooth"
      "coolercontrol"

      # Styles
      "stylix"
      "fonts"

      "virtualization"

      # Desktop GUI
      "xserver"
      "xwayland"
      #"gdm"
      "xdg-portal"
      #"gnome"
      "regreet"
      "hyprland"
    ];

    homeManagerModules = [
      "alacritty"
      "audio"
      "discord"
      "gnome"
      "kitty"
      "fonts"
      "firefox"
      "obs-studio"
      "obsidian" # note-taking app
      "stylix"
      "zathura" # PDF viewer
      # TODO:  Broken for now....
      "hyprland"
    ];
  };
}

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
      "greetd" # Doesn't work with gnome's session lock stuff... use if we don't need gnome
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
      "zathura" # PDF viewer
      # TODO:  Broken for now....
      "hyprland"
    ];
  };
}

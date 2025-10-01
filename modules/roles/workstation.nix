{
  flake.role.workstation = {
    aspects = [
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
      "alacritty"
      "discord"
      "kitty"
      "firefox"
      "obs-studio"
      "obsidian" # note-taking app
      "zathura" # PDF viewer
    ];
  };
}

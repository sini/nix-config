{
  flake.roles.workstation = {
    features = [
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
      "gdm"
      "gnome"
      "xdg-portal"
      #"regreet"
      #"hyprland"
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

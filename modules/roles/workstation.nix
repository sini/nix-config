{
  flake.roles.workstation = {
    features = [
      # Hardware modules
      "audio"
      "bluetooth"
      "coolercontrol"
      "ddcutil"

      # Styles
      "stylix"
      "fonts"

      "libvirt"

      # Desktop GUI
      "xserver"
      "xwayland"
      #"ananicy"

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

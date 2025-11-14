{
  flake.roles.workstation = {
    features = [
      # Hardware modules
      "audio"
      "bluetooth"
      "coolercontrol"
      "ddcutil"
      "keyboard"

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
      "kitty"
      "firefox"
      "obs-studio"
      "obsidian" # note-taking app
      "zathura" # PDF viewer

      # Messaging
      "discord"
      "telegram"
    ];
  };
}

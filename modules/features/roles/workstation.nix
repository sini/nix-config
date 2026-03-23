{
  features.workstation = {
    requires = [
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

      "gdm"
      "gnome"
      "xdg-portal"
      "alacritty"
      "kitty"
      "firefox"
      "obs-studio"
      "obsidian"
      "zathura"
    ];
  };
}

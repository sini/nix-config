{
  features.workstation = {
    provides.gpg.home =
      { pkgs, ... }:
      {
        services.gpg-agent.pinentry.package = pkgs.pinentry-gnome3;
      };

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

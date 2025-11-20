{
  flake.features.xdg-portal.nixos =
    {
      pkgs,
      ...
    }:
    {

      # environment.systemPackages = with pkgs; [
      #   xdg-launch
      #   xdg-utils # A set of command line tools that assist apps with a variety of desktop integration tasks
      #   xdg-user-dirs # Tool to help manage well known user directories like the desktop folder and the music folder
      #   xdg-dbus-proxy # DBus proxy for Flatpak and others
      #   xdg-desktop-portal # Desktop integration portals for sandboxed apps
      #   xdg-desktop-portal-gnome
      #   xdg-desktop-portal-gtk # Desktop integration portals for sandboxed apps
      #   #xdg-desktop-portal-hyprland
      #   inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
      #   desktop-file-utils
      #   libxdg_basedir # Implementation of the XDG Base Directory specification
      #   shared-mime-info # Database of common MIME types
      #   mime-types
      # ];

      xdg.portal = {
        enable = true;
        xdgOpenUsePortal = true;
        config = {
          common.default = [ "gtk" ];
          hyprland = {
            default = [
              "gtk"
              "hyprland"
            ];
          };
          niri = {
            default = [
              "gtk"
              "gnome"
            ];
          };
        };
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
          xdg-desktop-portal-gnome
          # xdg-desktop-portal-hyprland
        ];
      };
    };
}

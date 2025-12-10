{
  flake.features.xdg-portal.nixos =
    {
      inputs,
      pkgs,
      ...
    }:
    {
      security.pam.services = {
        gdm.enableGnomeKeyring = true;
        gdm-password.enableGnomeKeyring = true;
        login.enableGnomeKeyring = true;
        hyprlock.text = "auth include login";
        swaylock = {
          text = "auth include login";
        };
      };

      xdg.portal = {
        enable = true;
        xdgOpenUsePortal = true;
        config = {
          common = {
            default = [
              "gnome"
              "gtk"
            ];
          };
          hyprland = {
            default = [
              "hyprland"
              "gtk"
            ];
            "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
          };
          niri = {
            default = [
              "gtk"
              "gnome"
            ];
            "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
            "org.freedesktop.impl.portal.Access" = [ "gtk" ];
            "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
            "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
          };
          sway = {
            default = [
              "gtk"
              "wlr"
            ];
          };
        };
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
          xdg-desktop-portal-gnome
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
          xdg-desktop-portal-wlr
        ];
        configPackages = [
          pkgs.xdg-desktop-portal-gtk
          pkgs.xdg-desktop-portal-gnome
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal
          pkgs.niri
          pkgs.xdg-desktop-portal-wlr
        ];
      };

      # Necessary for xdg-portal home-manager module to work with useUserPackages enabled
      # https://github.com/nix-community/home-manager/pull/5184
      # TODO: When https://github.com/nix-community/home-manager/pull/6981 gets
      # merged this may no longer be needed
      environment.pathsToLink = [
        "/share/xdg-desktop-portal"
        "/share/applications"
      ];

    };
}

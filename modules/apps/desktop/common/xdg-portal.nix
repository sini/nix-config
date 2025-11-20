{
  flake.features.xdg-portal.nixos =
    {
      pkgs,
      ...
    }:
    {
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

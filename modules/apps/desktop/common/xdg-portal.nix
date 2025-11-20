{
  flake.features.xdg-portal.nixos =
    {
      inputs,
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
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
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

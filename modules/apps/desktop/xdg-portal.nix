{
  flake.modules.nixos.xdg-portal =
    {
      inputs,
      pkgs,
      ...
    }:
    {
      programs.hyprland.portalPackage =
        inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;

      xdg.portal = {
        enable = true;
        xdgOpenUsePortal = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
          xdg-desktop-portal-gnome # For GNOME
          xdg-desktop-portal

        ];
        configPackages = with pkgs; [
          xdg-desktop-portal-gtk
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
          xdg-desktop-portal-gnome # For GNOME
          xdg-desktop-portal
        ];
      };

    };
}

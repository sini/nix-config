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
        wlr.enable = true;
        xdgOpenUsePortal = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
          xdg-desktop-portal-wlr
        ];
      };

      environment.etc."xdg/portal/gtk.portal".text = ''
        [preferred]
        default=gtk
      '';
    };
}

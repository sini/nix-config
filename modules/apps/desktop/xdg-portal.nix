{
  flake.modules.nixos.xdg-portal =
    {
      config,
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
        wlr.enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-wlr
          xdg-desktop-portal-gtk
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
        ];
      };

      xdg.configFile."uwsm/env".source =
        "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

      environment.etc."xdg/portal/gtk.portal".text = ''
        [preferred]
        default=gtk
      '';
    };
}

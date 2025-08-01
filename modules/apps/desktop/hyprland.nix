{
  flake.modules.nixos.hyprland =
    {
      inputs,
      pkgs,
      ...
    }:
    let
      pkgs-unstable = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      # Enable cachix
      nix.settings = {
        substituters = [ "https://hyprland.cachix.org" ];
        trusted-substituters = [ "https://hyprland.cachix.org" ];
        trusted-public-keys = [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        ];
      };

      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1"; # wayland for electron apps
        # NOTE: https://github.com/NixOS/nixpkgs/issues/353990
        GSK_RENDERER = "cairo";
      };

      # TODO: Temporary workaround/test...
      hardware.graphics = {
        package = pkgs-unstable.mesa;

        # if you also want 32-bit support (e.g for Steam)
        enable32Bit = true;
        package32 = pkgs-unstable.pkgsi686Linux.mesa;
      };

      programs.hyprland = {
        enable = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        # make sure to also set the portal package, so that they are in sync
        portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;

        #systemd.setPath.enable = true;
        withUWSM = true; # recommended for most users
        xwayland.enable = true; # Xwayland can be disabled.
      };

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

      programs.uwsm.enable = true;
      #services.hypridle.enable = true;
      #programs.hyprlock.enable = true;

      # programs.gnupg.agent.pinentryPackage = pkgs.writeShellApplication {
      #   name = "pinentry-rofi";
      #   runtimeInputs = with pkgs; [ rofi-wayland ];
      #   text = ''
      #     exec ${pinentry-rofi}/bin/pinentry-rofi "$@"
      #   '';
      # };

      services = {
        dbus = {
          implementation = "broker";
          packages = with pkgs; [
            gcr
            gnome-settings-daemon
          ];
        };
        gnome.gnome-keyring.enable = true;

        devmon.enable = true;
        gvfs.enable = true;
        udisks2.enable = true;
      };
    };
}

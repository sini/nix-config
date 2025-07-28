{
  flake.modules.nixos.hyprland =
    {
      inputs,
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Enable cachix
      nix.settings = {
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

      programs.hyprland = {
        enable = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        # make sure to also set the portal package, so that they are in sync
        portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;

        withUWSM = true; # recommended for most users
        xwayland.enable = true; # Xwayland can be disabled.
      };

      # Screensharing
      # xdg.portal = {
      #   enable = true;
      #   extraPortals = with pkgs; [
      #     xdg-desktop-portal-gtk
      #     inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
      #   ];
      # };

      services = {
        dbus = {
          implementation = "broker";
          packages = with pkgs; [ gcr ];
        };
        devmon.enable = true;

        gvfs.enable = true;
        udisks2.enable = true;

        greetd = {
          enable = true;
          settings = {
            default_session = {
              command = lib.concatStringsSep " " [
                "${pkgs.greetd.tuigreet}/bin/tuigreet"
                "--cmd '${lib.getExe config.programs.uwsm.package} start hyprland'"
                "--asterisks"
                "--remember"
                "--remember-user-session"
                ''
                  --greeting "Hey you. You're finally awake."

                ''
              ];
              user = "greeter";
            };
          };
        };

        xserver = {
          enable = true;
          xkb = {
            layout = "us";
            variant = "";
          };
        };

      };
    };
}

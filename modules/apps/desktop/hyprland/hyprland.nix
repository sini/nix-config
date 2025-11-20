{
  flake.features.hyprland = {
    requires = [ "uwsm" ];
    nixos =
      {
        inputs,
        pkgs,
        ...
      }:
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

        programs.hyprland = {
          enable = true;
          package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
          portalPackage =
            inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
          withUWSM = true; # recommended for most users
          xwayland.enable = true; # Xwayland can be disabled.
        };

        security.pam.services.gdm.enableGnomeKeyring = true;
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
          gnome.sushi.enable = true;
          devmon.enable = true;
          gvfs.enable = true;
          udisks2.enable = true;
        };
      };
  };
}

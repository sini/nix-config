{
  flake.features.uwsm.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:

    {
      programs.uwsm.enable = true;

      environment = {
        systemPackages = [ pkgs.app2unit ];
        sessionVariables = {
          NIXOS_OZONE_WL = "1"; # wayland for electron apps
          # NOTE: https://github.com/NixOS/nixpkgs/issues/353990
          GSK_RENDERER = "cairo";
          APP2UNIT_SLICES = "a=app-graphical.slice b=background-graphical.slice s=session-graphical.slice";
          # Even though I use the -t service flag pretty much everywhere in my
          # config still keep the default behaviour as scope because this is
          # generally how apps should be launched if we interactively run `app2unit
          # app.desktop` in a terminal. Launching with a keybind, launcher or
          # script should run the the app in a service since there's no value in
          # process or input/output inheritance in these cases.

          APP2UNIT_TYPE = "scope";
        };
      };

      # Taken from: https://github.com/JManch/nixos/blob/main/modules/nixos/system/desktop/root.nix

      # Fix the session slice for home-manager services. I don't think it's
      # possible to do drop-in overrides like this with home-manager.

      # You'd expect service overrides with `systemd.user.services` to only set
      # what you've defined but confusingly Nixpkgs sets the service's PATH by
      # default in an undocumented way. This overrides the PATH set in the
      # systemd user environment and breaks our portal services.
      # https://github.com/NixOS/nixpkgs/blame/18bcb1ef6e5397826e4bfae8ae95f1f88bf59f4f/nixos/lib/systemd-lib.nix#L512

      # For system services this isn't an issue since `systemctl
      # show-environment` is basically empty anyway. For user services
      # however, this is a nasty pitfall. Note: this only affects overrides
      # of units provided in packages; not those declared with Nix.

      # We workaround this by instead defining plain unit files containing just
      # the set text. Setting `systemd.user.services.<name>.paths = mkForce []`
      # also works (it still adds extra Environment= vars however).
      # systemd.user.units =
      #   lib.genAttrs
      #     [
      #       "at-spi-dbus-bus.service"
      #       "xdg-desktop-portal-gtk.service"
      #       "xdg-desktop-portal-hyprland.service"
      #       "xdg-desktop-portal.service"
      #       "xdg-document-portal.service"
      #       "xdg-permission-store.service"
      #     ]
      #     (_: {
      #       overrideStrategy = "asDropin";
      #       text = ''
      #         [Service]
      #         Slice=session-graphical.slice
      #       '';
      #     });
      # xdg.portal.enable = lib.mkForce false;

      systemd.user.services.fumon = {
        enable = true;
        wantedBy = [ "graphical-session.target" ];
        path = lib.mkForce [ ];
        serviceConfig.ExecStart = [
          "" # to replace original ExecStart
          (lib.getExe' config.programs.uwsm.package "fumon")
        ];
      };
    };
}

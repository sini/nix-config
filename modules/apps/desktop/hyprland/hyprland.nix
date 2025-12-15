{
  flake.features.hyprland = {
    requires = [
      "xdg-portal"
      "uwsm"
    ];
    nixos =
      {
        inputs,
        pkgs,
        lib,
        ...
      }:
      {

        environment.systemPackages = with pkgs; [
          xwayland-satellite
          wlogout
          swaylock
        ];

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

        systemd.user.services.hyprpolkitagent = {
          path = lib.mkForce [ ]; # reason explained in desktop/default.nix
          serviceConfig.Slice = "session-graphical.slice";
          wantedBy = [ "graphical-session.target" ];
        };

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

    home =
      {
        config,
        inputs,
        lib,
        pkgs,
        ...
      }:
      {

        imports = [
          inputs.hyprland.homeManagerModules.default
        ];

        home.packages = with pkgs; [
          hyprpicker
          hyprcursor
          libnotify
          networkmanagerapplet # bin: nm-connection-editor
          blueman # bin: blueman-manager
          pwvucontrol
          snapshot
        ];

        xdg.configFile."uwsm/env".source =
          "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

        programs = {
          wofi.enable = true;
          rofi = {
            enable = true;
          };
        };

        systemd.user.services.hyprpolkitagent = {
          Unit.ConditionEnvironment = lib.mkForce [
            "|XDG_CURRENT_DESKTOP=Hyprland"
            "|XDG_CURRENT_DESKTOP=niri"
          ];
        };

        systemd.user.services.hyprpaper = {
          Unit.ConditionEnvironment = lib.mkForce [
            "|XDG_CURRENT_DESKTOP=Hyprland"
            "|XDG_CURRENT_DESKTOP=niri"
          ];
          Service.Slice = "background-graphical.slice";
        };

        services = {
          # clipman.enable = true;
          # hypridle.enable = true;
          hyprpaper = {
            enable = true;
            settings = {
              ipc = "on";
              splash = false;
            };
          };
        };

        # xdg.configFile."uwsm/env".source =
        #   "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh";

        # xdg.configFile."uwsm/env".text = ''
        #   # Explicitly source the Home Manager session variables
        #   . "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh"
        #   export __HM_SESS_VARS_SOURCED=
        # '';
        wayland.windowManager.hyprland = {
          enable = true;
          # Managed by system configuration
          package = null;
          portalPackage = null;

          # Disabled because it conflicts with uwsm
          # https://wiki.hypr.land/Useful-Utilities/Systemd-start/
          systemd.enable = false;

          xwayland.enable = true;

          settings = {
            exec-once = [
              "uwsm finalize"
            ];
            ecosystem = {
              #enforce_permissions = true;
              no_donation_nag = true;
            };
            misc = {
              # vrr = 1;
              disable_hyprland_logo = true;
            };
            # monitor = [ ",highres,auto,1" ];
            xwayland.force_zero_scaling = true;
          };
        };

      };
  };
}

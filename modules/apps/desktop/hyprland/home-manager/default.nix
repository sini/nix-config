{
  flake.features.hyprland.home =
    {
      inputs,
      config,
      pkgs,
      ...
    }:
    let
      easymotion = inputs.hyprland-easymotion.packages.${pkgs.system}.hyprland-easymotion;
      #hyprsplit = inputs.hyprsplit.packages.${pkgs.system}.hyprsplit;
      split-monitor-workspaces =
        inputs.hyprland-split-monitor-workspaces.packages.${pkgs.system}.split-monitor-workspaces;
    in
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

      # xdg.configFile."uwsm/env".source =
      #   "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

      programs = {
        hyprlock.enable = true;
        wofi.enable = true;
        rofi = {
          enable = true;
        };
      };

      services = {
        clipman.enable = true;
        hypridle.enable = true;
        hyprpaper = {
          enable = true;
          settings = {
            ipc = "on";
            splash = false;
          };
        };
      };

      xdg.configFile."uwsm/env".source =
        "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

      wayland.windowManager.hyprland = {
        enable = true;
        # Managed by system configuration
        package = null;
        portalPackage = null;

        # Disabled because it conflicts with uwsm
        # https://wiki.hypr.land/Useful-Utilities/Systemd-start/
        systemd.enable = false;

        xwayland.enable = true;

        plugins = [
          easymotion
          #hyprsplit
          split-monitor-workspaces
        ];
        # ++ with inputs.hyprland-plugins.packages.${pkgs.system};
        #   [
        #     # hyprbars
        #     #hyprexpo
        #     # hyprtrails
        #     # hyprwinwrap
        #   ];

        settings = {
          exec-once = [
            "uwsm finalize"
          ];
          ecosystem = {
            #enforce_permissions = true;
            no_donation_nag = true;
          };
          misc = {
            vrr = 1;
            disable_hyprland_logo = true;
          };
          monitor = [ ",highres,auto,1" ];
          xwayland.force_zero_scaling = true;

        };
      };

    };
}

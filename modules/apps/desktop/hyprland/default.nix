{
  flake.modules.homeManager.hyprland =
    { inputs, pkgs, ... }:
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

      wayland.windowManager.hyprland = {
        enable = true;
        # Disabled because it conflicts with uwsm
        # https://wiki.hypr.land/Useful-Utilities/Systemd-start/
        systemd.enable = false;

        xwayland.enable = true;

        settings = {
          exec-once = [
            "uwsm finalize"
          ];
          ecosystem = {
            enforce_permissions = true;
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

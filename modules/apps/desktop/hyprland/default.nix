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
          xwayland.force_zero_scaling = true;
        };
      };

    };
}

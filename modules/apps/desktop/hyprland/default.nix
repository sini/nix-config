{
  flake.modules.homeManager.hyprland =
    { inputs, pkgs, ... }:
    {

      imports = [
        inputs.hyprland.homeManagerModules.default
        #   # ./apps/hyprlock.nix
        #   # ./apps/swayidle.nix
        #   ./apps/cliphist.nix
        #   ./apps/gtk.nix
        #   ./apps/hypridle.nix
        #   ./apps/hyprpanel.nix
        #   ./apps/hyprpaper.nix # wallpaper
        #   ./apps/hyprsunset.nix
        #   ./apps/per-window-layout.nix
        #   ./apps/polkit-agent.nix # sudo password prompt
        #   ./apps/qt.nix
        #   ./apps/rofi.nix
        #   ./apps/swaylock.nix
        #   ./apps/wayland-pipewire-idle-inhibit.nix
        #   ./apps/xdg-mime.nix # file association

        #   ./animations.nix
        #   ./cursor.nix
        #   ./decorations.nix
        #   ./input.nix
        #   ./keybinds.nix
        #   ./tiling.nix
        #   ./window-rules.nix
        #   ./workspaces.nix

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
        systemd.enable = true;
        systemd.enableXdgAutostart = true;
        xwayland.enable = true;

        settings = {

          xwayland.force_zero_scaling = true;

        };
      };

    };
}

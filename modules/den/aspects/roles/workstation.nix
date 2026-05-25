{ den, ... }:
{
  den.aspects.roles.workstation = {
    colmena-tags = [ "workstation" ];
    includes = with den.aspects; [
      # Hardware
      hardware.audio
      hardware.bluetooth
      hardware.coolercontrol
      hardware.ddcutil
      hardware.keyboard

      # Theming
      desktop.stylix
      desktop.fonts

      # Virtualization
      virtualization.libvirt

      # Desktop
      desktop.xserver
      desktop.xwayland
      desktop.gdm
      desktop.gnome
      desktop.xdg-portal

      # Apps
      apps.alacritty
      apps.kitty
      apps.firefox
      apps.obs-studio
      apps.obsidian
      apps.zathura
    ];

    homeManager =
      { pkgs, ... }:
      {
        services.gpg-agent.pinentry.package = pkgs.pinentry-gnome3;
      };
  };
}

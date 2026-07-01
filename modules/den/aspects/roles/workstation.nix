{ den, ... }:
{
  den.aspects.roles.workstation = {
    includes = with den.aspects; [
      # Hardware
      hardware.audio
      hardware.bluetooth
      hardware.coolercontrol
      hardware.ddcutil
      hardware.keyboard

      # Theming
      desktop.style.stylix
      desktop.style.fonts

      # Virtualization
      virtualization.libvirt

      # Desktop
      desktop.xserver
      desktop.xwayland
      desktop.gdm
      desktop.gnome
      desktop.xdg-portal

      # Apps
      apps.terminals.alacritty
      apps.terminals.kitty
      apps.browsers.firefox
      apps.browsers.chromium

      apps.dev.security.opkssh-client

      apps.mail.protonmail

      apps.productivity.obs-studio
      apps.productivity.obsidian
      apps.productivity.zathura
    ];
  };
}

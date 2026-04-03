# Workstation role: desktop environment with hardware support, GUI apps, and libvirt.
{ den, lib, ... }:
{
  den.aspects.workstation = {
    includes = [
      # Hardware modules
      den.aspects.audio
      den.aspects.bluetooth
      den.aspects.coolercontrol
      den.aspects.ddcutil
      den.aspects.keyboard

      # Styles
      den.aspects.stylix
      den.aspects.fonts

      den.aspects.libvirt

      # Desktop GUI
      den.aspects.xserver
      den.aspects.xwayland

      den.aspects.gdm
      den.aspects.gnome
      den.aspects.xdg-portal
      den.aspects.alacritty
      den.aspects.kitty
      den.aspects.firefox
      den.aspects.obs-studio
      den.aspects.obsidian
      den.aspects.zathura
    ]
    ++ lib.attrValues den.aspects.workstation._;

    _ = {
      gpg-pinentry = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            services.gpg-agent.pinentry.package = pkgs.pinentry-gnome3;
          };
      };
    };
  };
}

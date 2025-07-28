{ lib, pkgs, ... }:
let
  i = lib.hm.gvariant.mkUint32;
in
{
  qt = {
    enable = true;
    style.name = "Adwaita-dark";
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";

    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-schedule-automatic = true;
      night-light-temperature = i 4500;
    };
  };
}

{ lib, ... }:
let
  i = lib.hm.gvariant.mkUint32;
in
{
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/power" = {
      idle-dim = false;
      power-button-action = "interactive";
      sleep-inactive-ac-type = "nothing";
    };
    "org/gnome/desktop/session".idle-delay = i 0;
  };
}

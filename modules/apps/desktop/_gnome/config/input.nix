{ lib, ... }:
let
  i = lib.hm.gvariant.mkUint32;
  t = lib.hm.gvariant.mkTuple;
in
{
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      # Use different keyboard language for each window
      per-window = true;
      sources = [
        (t [
          "xkb"
          "us"
        ])
        (t [
          "xkb"
          "ru"
        ])
      ];
    };

    "org/gnome/desktop/peripherals/keyboard" = {
      delay = i 275;
      repeat-interval = i 35;
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      click-method = "areas";
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
    };
  };
}

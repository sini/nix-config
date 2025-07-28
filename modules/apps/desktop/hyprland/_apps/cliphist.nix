{ lib, pkgs, ... }:
{

  wayland.windowManager.hyprland.settings.bind =
    let
      cliphist = "${pkgs.cliphist}/bin/cliphist";
      rofi = lib.getExe pkgs.rofi-wayland;
      wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
      wtype = "${pkgs.wtype}/bin/wtype";
    in
    [
      "SUPER, V, exec, ${cliphist} list | ${rofi} -dmenu -p '󰍜 ' | ${cliphist} decode | ${wl-copy} && ${wtype} -M ctrl -P v -m ctrl -p v"
    ];

  services.cliphist = {
    enable = true;
    allowImages = true;
    systemdTargets = [ "graphical-session.target" ];
  };

}

{ vars, ... }:
let
  wallpaper-uri = "file://${vars.wallpaper}";
in
{
  imports = [
    ./dark-mode.nix
    ./extensions.nix
    ./input.nix
    ./keybinds.nix
    ./pop-shell.nix
    ./power.nix
  ];

  dconf.settings = {

    "org/gnome/shell" = {
      favorite-apps = [
        "firefox.desktop"
        "kitty.desktop"
        "steam.desktop"
        "org.gnome.Nautilus.desktop"
      ];
    };

    "org/gnome/desktop/background" = {
      picture-uri = wallpaper-uri;
      picture-uri-dark = wallpaper-uri;
    };

    "org/gnome/desktop/screensaver" = {
      picture-uri = wallpaper-uri;
      picture-uri-dark = wallpaper-uri;
    };

    "org/gnome/mutter" = {
      center-new-windows = true;
      dynamic-workspaces = true;
      edge-tiling = true;
      experimental-features = [ "scale-monitor-framebuffer" ]; # hidpi
      workspaces-only-on-primary = true;
    };

    "org/gnome/shell/app-switcher" = {
      current-workspace-only = true;
    };

    "org/gnome/desktop/wm/preferences" = {
      resize-with-right-button = true;
      focus-mode = "sloppy";
    };

    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
      sort-directories-first = true;
      view-type = "list";
    };
  };
}

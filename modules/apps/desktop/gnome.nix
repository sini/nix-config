{
  flake.modules.nixos.gnome =
    {
      pkgs,
      ...
    }:
    {
      environment = {
        systemPackages = with pkgs; [
          gnome-tweaks
          dconf-editor
          gnomeExtensions.pop-shell
          gnomeExtensions.appindicator
          gnomeExtensions.pip-on-top
          gnomeExtensions.gamemode-shell-extension
        ];
        gnome.excludePackages = with pkgs; [
          epiphany
          geary
          gnome-font-viewer
          gnome-maps
          gnome-system-monitor
          gnome-tour
        ];
      };

      services = {
        # TODO: Move display manager to regreet or something
        displayManager = {
          gdm = {
            enable = true;
            autoSuspend = false;
            wayland = true;
          };
        };

        desktopManager.gnome.enable = true;

        udev.packages = with pkgs; [ gnome-settings-daemon ];

      };

      programs.nautilus-open-any-terminal = {
        enable = true;
        terminal = "kitty";
      };

    };

  flake.modules.homeManager.gnome =
    { lib, pkgs, ... }:
    {
      dconf.settings = {

        "org/gnome/shell" = {
          favorite-apps = [
            "firefox.desktop"
            "kitty.desktop"
            "steam.desktop"
            "org.gnome.Nautilus.desktop"
          ];
        };

        # "org/gnome/desktop/background" = {
        #   picture-uri = wallpaper-uri;
        #   picture-uri-dark = wallpaper-uri;
        # };

        # "org/gnome/desktop/screensaver" = {
        #   picture-uri = wallpaper-uri;
        #   picture-uri-dark = wallpaper-uri;
        # };

        "org/gnome/desktop/ally/applications" = {
          "screen-reader-enabled" = false;
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

        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = [
            "pip-on-top@rafostar.github.com"
            "appindicatorsupport@rgcjonas.gmail.com"
            "gamemodeshellextension@trsnaqe.com"
          ];
        };

        "org/gnome/shell/extensions/pip-on-top" = {
          stick = true;
        };

        "org/gnome/shell/extensions/gamemodeshellextension" = {
          show-icon-only-when-active = true;
        };

        "org/gnome/settings-daemon/plugins/color" = {
          night-light-enabled = true;
          night-light-schedule-automatic = true;
          night-light-temperature = lib.hm.gvariant.mkUint32 4500;
        };

        "org/gnome/TextEditor".keybindings = "vim";

        "org/gnome/desktop/wm/keybindings" = {
          close = [ "<Super>q" ];
          move-to-workspace-1 = [ "<Shift><Super>1" ];
          move-to-workspace-2 = [ "<Shift><Super>2" ];
          move-to-workspace-3 = [ "<Shift><Super>3" ];
          move-to-workspace-4 = [ "<Shift><Super>4" ];
          move-to-workspace-5 = [ "<Shift><Super>5" ];
          move-to-workspace-6 = [ "<Shift><Super>6" ];
          move-to-workspace-7 = [ "<Shift><Super>7" ];
          move-to-workspace-8 = [ "<Shift><Super>8" ];
          move-to-workspace-9 = [ "<Shift><Super>9" ];
          switch-to-workspace-1 = [ "<Super>1" ];
          switch-to-workspace-2 = [ "<Super>2" ];
          switch-to-workspace-3 = [ "<Super>3" ];
          switch-to-workspace-4 = [ "<Super>4" ];
          switch-to-workspace-5 = [ "<Super>5" ];
          switch-to-workspace-6 = [ "<Super>6" ];
          switch-to-workspace-7 = [ "<Super>7" ];
          switch-to-workspace-8 = [ "<Super>8" ];
          switch-to-workspace-9 = [ "<Super>9" ];
          toggle-fullscreen = [ "<Super>f" ];
        };

        "org/gnome/shell/keybindings" = {
          # Remove the default hotkeys for opening favorited applications.
          switch-to-application-1 = [ ];
          switch-to-application-2 = [ ];
          switch-to-application-3 = [ ];
          switch-to-application-4 = [ ];
          switch-to-application-5 = [ ];
          switch-to-application-6 = [ ];
          switch-to-application-7 = [ ];
          switch-to-application-8 = [ ];
          switch-to-application-9 = [ ];
        };

        "org/gnome/settings-daemon/plugins/media-keys" = {
          next = [ "<Shift><Control>n" ];
          previous = [ "<Shift><Control>p" ];
          play = [ "<Shift><Control>space" ];
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/"
          ];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>Return";
          command = "kitty";
          name = "kitty";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          binding = "<Shift><Super>h";
          command = "kitty -e htop";
          name = "htop";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" =
          let
            # show images in kitty
            spotifyPlayerCMD = "kitty -o term=xterm-kitty -e spotify_player";
          in
          {
            binding = "<Shift><Super>s";
            command = spotifyPlayerCMD;
            name = "spotify-player";
          };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
          binding = "<Super>e";
          command = "kitty -e yazi";
          name = "File Manager";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
          binding = "<Shift><Super>n";
          command = "kitty -e nvtop";
          name = "nvtop";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
          binding = "<Super>Print";
          command = "${pkgs.bash}/bin/bash -c '${pkgs.wl-clipboard}/bin/wl-paste | ${pkgs.swappy}/bin/swappy -f -'";
          name = "Edit clipboard image";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6" = {
          binding = "<Super><Shift>Return";
          command = "kitty -e vim";
          name = "vim";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7" = {
          binding = "<Super><Shift>B";
          command = "firefox --new-window";
          name = "Firefox new window";
        };

      };
    };

}

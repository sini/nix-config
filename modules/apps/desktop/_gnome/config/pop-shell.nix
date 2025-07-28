{ lib, ... }:
# NOTE: dconf schema: https://github.com/pop-os/shell/blob/master_noble/schemas/org.gnome.shell.extensions.pop-shell.gschema.xml
# mappings https://community.frame.work/t/ubuntu-popos-shell-how-do-you-configure-the-keyboard-shortcuts-to-try-to-mimic-my-i3wm-config/6223/2
# official default shortcuts https://support.system76.com/articles/pop-keyboard-shortcuts/
let
  mf = lib.mkForce;
  f = lib.mkForce false;
  t = lib.mkForce true;
  i = lib.hm.gvariant.mkUint32;
in
{
  dconf.settings = {

    "org/gnome/shell" = {
      disable-user-extensions = f;
      enabled-extensions = [ "pop-shell@system76.com" ];
    };

    "org/gnome/shell/keybindings" = {
      toggle-quick-settings = mf [ ];
    };

    "org/gnome/mutter" = {
      center-new-windows = f;
      edge-tiling = f;
      workspaces-only-on-primary = t;
    };

    "org/gnome/desktop/wm/preferences" = {
      resize-with-right-button = f;
      # focus-mode = lib.mkForce "click";
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      screensaver = mf [ "<Shift><Control><Super>l" ];
    };

    "org/gnome/desktop/wm/keybindings" = {
      minimize = mf [ "<Shift><Control><Super>h" ];
      maximize = mf [ ];
      unmaximize = mf [ ];
    };

    "org/gnome/shell/extensions/pop-shell" = {
      tile-by-default = true;
      toggle-tiling = [ "<Super>y" ];

      # gaps
      gap-inner = i 2;
      gap-outer = i 0;
      smart-gaps = true; # no gaps on single window

      # # hint
      # active-hint = true;
      # active-hint-border-radius = i 7;
      # hint-color-rgba = "rgba(198,160,246,0.85)"; # mauve #c6a0f6

      # window
      show-title = false;
      toggle-floating = [ "<Super>g" ];
      toggle-stacking = [ "<Super>s" ];
      # toggle-stacking-global = [ "<Super>s" ];

      # movement
      mouse-cursor-follows-active-window = true;
      mouse-cursor-focus-location = i 4;
      focus-left = [ "<Super>h" ];
      focus-down = [ "<Super>j" ];
      focus-up = [ "<Super>k" ];
      focus-right = [ "<Super>l" ];

      # tile manipulation
      tile-enter = [ "<Super>r" ];
      tile-accept = [ "Return" ];
      tile-reject = [ "Escape" ];
      # tile-move-up = [ "slash" ];
      # tile-resize-up = [ "<Shift>slash" ];

      # launcher
      # activate-launcher = ["<Super>slash"];
      # fullscreen-launcher = true; # allow over fullscreen

      # ???
      # snap-to-grid = true;
      # stacking-with-mouse = false;
      # show-skip-taskbar = true;

      # search = [ "<Super>d" ];
      tile-move-left = [ "<Shift>h" ];
      tile-move-down = [ "<Shift>j" ];
      tile-move-up = [ "<Shift>k" ];
      tile-move-right = [ "<Shift>l" ];
      # tile-resize-down = [ "<Super>i" ];
      # tile-resize-left = [ "<Super>u" ];
      # tile-resize-right = [ "<Super>p" ];
      # tile-resize-up = [ "<Super>o" ];
      # tile-swap-down = [ "j" ];
      # tile-swap-left = [ "h" ];
      # tile-swap-right = [ "l" ];
      # tile-swap-up = [ "k" ];

      # workspaces
      # pop-monitor-down = [ ];
      # pop-monitor-up = [ ];
      # pop-monitor-left = [ ];
      # pop-monitor-right = [ ];
      # pop-workspace-down = [ ];
      # pop-workspace-up = [ ];

      # column-size = mkUint32 64;
      # management-orientation = [ "o" ];
      # row-size = mkUint32 64;
      # tile-move-down-global = [ "<Shift><Super>Down" ];
      # tile-move-down = [ "<Shift><Super>Down" ];
      # tile-move-left-global = [ "<Shift><Super>Left" ];
      # tile-move-left = [ "<Shift><Super>Left" ];
      # tile-move-right-global = [ "<Shift><Super>Right" ];
      # tile-move-right = [ "<Shift><Super>Right" ];
      # tile-move-up-global = [ "<Shift><Super>Up" ];
      # tile-move-up = [ "<Shift><Super>Up" ];
      # tile-orientation = [ "<Super>h" "<Super>v" ];
      # tile-resize-down = [ "Down" ];
      # tile-resize-left = [ "Left" ];
      # tile-resize-right = [ "Right" ];
      # tile-resize-up = [ "Up" ];
      # tile-swap-down = [ ];
      # tile-swap-left = [ ];
      # tile-swap-right = [ ];
      # tile-swap-up = [ ];

    };
  };

  # xdg.configFile."pop-shell/config.json" = # json
  #   ''
  #     {
  #       "float": [
  #         {
  #           "class": "org.gnome.Settings"
  #         },
  #         {
  #           "class": "org.gnome.Loupe"
  #         },
  #         {
  #           "class": "com.github.finefindus.eyedropper"
  #         },
  #         {
  #           "class": "org.gnome.Calculator"
  #         },
  #         {
  #           "class": "org.gnome.Extensions"
  #         },
  #         {
  #           "class": "org.gnome.tweaks"
  #         },
  #         {
  #           "class": "pop-shell-exceptions"
  #         },
  #         {
  #           "class": "pavucontrol"
  #         },
  #         {
  #           "class": "nvidia-settings"
  #         },
  #         {
  #           "class": "gcolor3"
  #         },
  #         {
  #           "class": "org.gnome.clocks"
  #         },
  #         {
  #           "class": "org.gnome.Snapshot"
  #         },
  #         {
  #           "class": "steam",
  #           "title": "Steam Settings"
  #         },
  #         {
  #           "class": "org.telegram.desktop",
  #           "title": "TelegramDesktop"
  #         },
  #         {
  #           "class": "msiexec.exe"
  #         },
  #         {
  #           "class": "CrittersForSale.x86_64"
  #         },
  #         {
  #           "class": "lutris",
  #           "title": "Log for nfs-ps (wine)"
  #         },
  #         {
  #           "class": "steam",
  #           "title": "Steam - Browser"
  #         },
  #         {
  #           "class": "mpv"
  #         },
  #         {
  #           "class": "Vncviewer",
  #           "title": "TigerVNC Viewer"
  #         },
  #         {
  #           "class": "Imager"
  #         },
  #         {
  #           "class": "steam",
  #           "title": "Sign in to Steam"
  #         }
  #       ],
  #       "skiptaskbarhidden": [],
  #       "log_on_focus": false
  #     }
  #   '';

}

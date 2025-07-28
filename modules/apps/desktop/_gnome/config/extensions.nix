_: {
  dconf.settings = {
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
  };
}

{ pkgs, vars, ... }:
{

  home-manager.users.${vars.username} = import ./config;

  environment.systemPackages = with pkgs; [
    gnome-tweaks
    dconf-editor
    gnomeExtensions.pop-shell
    gnomeExtensions.appindicator
    gnomeExtensions.pip-on-top
    gnomeExtensions.gamemode-shell-extension
  ];

  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    xkb = {
      layout = vars.kb_layouts;
      options = "grp:win_space_toggle";
    };
  };

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = vars.terminal.name;
  };

}

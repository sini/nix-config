{
  pkgs,
  vars,
  osConfig,
  ...
}:
let

  themeSource = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "rofi";
    rev = "c24a212a6b07c2d45f32d01d7f10b4d88ddc9f45";
    sha256 = "sha256-WGYEA4Q7UvSaRDjP/DiEtfXjvmWbewtdyJWRpjhbZgg=";
  };

  uwsm = "${pkgs.uwsm}/bin/uwsm";
  prefix = if osConfig.programs.hyprland.withUWSM then "${uwsm} app --" else "";
  pkill = "${pkgs.procps}/bin/pkill";
  wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
  wtype = "${pkgs.wtype}/bin/wtype";

in
{

  xdg.configFile."rofi/catppuccin-mocha.rasi".source =
    "${themeSource}/themes/catppuccin-macchiato.rasi";

  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    terminal = "${vars.terminal.name} -e";
    theme = "${themeSource}/catppuccin-default.rasi";

    plugins = with pkgs; [
      rofi-calc
      rofi-emoji-wayland
    ];

    extraConfig = {
      modi = "drun,run,calc,ssh,emoji";
      display-drun = "󰘔 ";
      display-calc = "󱖦 ";
      display-ssh = " ";
      display-emoji = "󰞅 ";
      display-run = "󰲌 ";
      hover-select = true;
      show-icons = true;
      run-command = "${prefix} {cmd}";
    };

  };

  wayland.windowManager.hyprland.settings.bind = [
    ''
      SUPER, A, exec, ${pkill} rofi || rofi -show drun -no-history -calc-command "echo -n '{result}' | ${wl-copy} && ${wtype} -M ctrl -P v -m ctrl -p v"
    ''
  ];

}

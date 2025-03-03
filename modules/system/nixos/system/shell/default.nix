{
  options,
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.system.shell;
in
{
  options.system.shell = with types; {
    shell = mkOpt (enum [
      "nushell"
      "fish"
      "zsh"
    ]) "zsh" "What shell to use";
  };

  config = {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
    };

    environment.systemPackages = with pkgs; [
      eza
      bat
      nitch
      zoxide
      starship
    ];

    users.defaultUserShell = pkgs.${cfg.shell};
    users.users.root.shell = pkgs.bashInteractive;

  };
}

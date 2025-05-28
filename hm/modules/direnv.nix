{
  lib,
  config,
  ...
}:
let
  cfg = config.programs.direnv;
in
{
  programs.direnv = lib.mkIf cfg.enable {
    enableZshIntegration = config.programs.zsh.enable;
    enableNushellIntegration = config.programs.nushell.enable;
  };
}

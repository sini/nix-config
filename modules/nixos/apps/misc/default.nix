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
  cfg = config.apps.misc;
in
{
  options.apps.misc = with types; {
    enable = mkBoolOpt false "Enable or disable misc apps";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Development
      git
      git-remote-gcrypt
      bat
      eza
      fzf
      fd

      # Util
      unzip
      sshfs
      btop
      ffmpeg
      python3
    ];
  };
}

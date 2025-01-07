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
  cfg = config.suites.common;
in
{
  options.suites.common = with types; {
    enable = mkBoolOpt false "Enable the common suite";
  };

  config = mkIf cfg.enable {
    system = {
      nix.enable = true;
      security.doas.enable = true;
    };

    hardware.networking.enable = true;


    services.ssh.enable = true;
    programs.dconf.enable = true;

    environment.systemPackages = [
      # pkgs.bluetuith
      pkgs.${namespace}.sys
    ];

    system = {
      fonts.enable = true;
      locale.enable = true;
      time.enable = true;
      xkb.enable = true;
    };
  };
}

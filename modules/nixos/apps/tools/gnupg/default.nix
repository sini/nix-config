{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.apps.tools.gnupg;
in
{
  options.apps.tools.gnupg = with types; {
    enable = mkBoolOpt false "Enable gnupg";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.pinentry
      pkgs.pinentry-curses
    ];

    services.pcscd.enable = true;
    programs.gnupg.agent = {
      enable = true;
      pinentryFlavor = "curses";
      enableSSHSupport = true;
    };

    environment.variables = {
      GNUPGHOME = "$XDG_DATA_HOME/gnupg";
    };
  };
}

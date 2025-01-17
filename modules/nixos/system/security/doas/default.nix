{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.system.security.doas;
in {
  options.system.security.doas = {
    enable = mkBoolOpt true "Whether or not to replace sudo with doas.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      doas
      doas-sudo-shim
    ];

    # Disable sudo
    security.sudo.enable = false;

    # Enable and configure `doas`.
    security.doas = {
      enable = true;
      wheelNeedsPassword = false;
      extraRules = [
        {
          users = [config.user.name];
          noPass = true;
          keepEnv = true;
        }
      ];
    };

  };
}
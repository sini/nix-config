{ config, ... }:
let
  user = config.flake.meta.user.username;
in
{
  flake.features.sudo.nixos = {

    # Enable sudo-rs instead of c-based sudo.
    security.sudo.enable = false;
    security.sudo-rs = {
      enable = true;
      execWheelOnly = true;
      wheelNeedsPassword = false;
    };

    # Enable and configure `doas`.
    security.doas = {
      enable = true;
      wheelNeedsPassword = false;
      extraRules = [
        {
          users = [ user ];
          noPass = true;
          keepEnv = true;
        }
      ];
    };

    impermanence.ignorePaths = [
      "/etc/sudoers"
      "/etc/doas.conf"
    ];
  };
}

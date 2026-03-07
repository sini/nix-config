{ config, ... }:
let
  user = config.flake.meta.user.username;
in
{
  flake.features.sudo.nixos = {

    security = {
      # Enable sudo-rs instead of c-based sudo.
      sudo.enable = false;
      sudo-rs = {
        enable = true;
        execWheelOnly = true;
        wheelNeedsPassword = false;
      };

      # Enable and configure `doas`.
      doas = {
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
    };

    impermanence.ignorePaths = [
      "/etc/sudoers"
      "/etc/doas.conf"
    ];
  };
}

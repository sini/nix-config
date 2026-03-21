{
  features.sudo.linux =
    {
      lib,
      users,
      ...
    }:
    let
      enabledUserNames = builtins.attrNames (lib.filterAttrs (_: u: u.system.enable or false) users);
    in
    {
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
              users = enabledUserNames;
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

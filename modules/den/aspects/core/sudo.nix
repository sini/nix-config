# sudo — sudo-rs + doas configuration.
#
# Ported from main:modules/_legacy/core/sudo.nix.
_: {
  den.aspects.core.sudo = {
    nixos =
      { host, ... }:
      {
        security = {
          sudo.enable = false;
          sudo-rs = {
            enable = true;
            execWheelOnly = true;
            wheelNeedsPassword = false;
          };
          doas = {
            enable = true;
            wheelNeedsPassword = false;
            extraRules = [
              {
                users = builtins.attrNames (host.users or { });
                noPass = true;
                keepEnv = true;
              }
            ];
          };
        };
      };
  };
}

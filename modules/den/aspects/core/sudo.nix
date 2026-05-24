# sudo — sudo-rs + doas configuration.
#
# Ported from main:modules/_legacy/core/sudo.nix.
_: {
  den.aspects.core.sudo = {
    nixos =
      { resolved-users, ... }:
      let
        userNames = map (u: u.name) resolved-users;
      in
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
                users = userNames;
                noPass = true;
                keepEnv = true;
              }
            ];
          };
        };
      };
  };
}

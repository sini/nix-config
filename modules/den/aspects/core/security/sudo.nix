# sudo — sudo-rs + doas configuration.
#
# Ported from main:modules/_legacy/core/sudo.nix.
_: {
  den.aspects.core.security.sudo = {
    nixos = {
      security = {
        sudo.enable = false;
        sudo-rs = {
          enable = true;
          execWheelOnly = true;
          wheelNeedsPassword = false;
        };
      };
    };
  };
}

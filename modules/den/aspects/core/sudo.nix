# sudo — sudo-rs + doas configuration.
#
# Ported from main:modules/_legacy/core/sudo.nix.
{ den, lib, ... }:
{
  den.aspects.core.sudo = {
    nixos =
      { lib, ... }:
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
          };
        };
      };
  };
}

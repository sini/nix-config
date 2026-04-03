{ den, ... }:
{
  den.aspects.sudo = den.lib.perHost {
    nixos = {
      security = {
        # Enable sudo-rs instead of c-based sudo
        sudo.enable = false;
        sudo-rs = {
          enable = true;
          execWheelOnly = true;
          wheelNeedsPassword = false;
        };

        # Enable and configure doas for wheel group
        doas = {
          enable = true;
          wheelNeedsPassword = false;
        };
      };
    };
  };
}

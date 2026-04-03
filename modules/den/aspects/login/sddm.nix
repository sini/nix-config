{ den, ... }:
{
  den.aspects.sddm = den.lib.perHost {
    nixos = {
      services = {
        displayManager = {
          sddm = {
            enable = true;
            wayland.enable = true;
          };
        };
      };
    };
  };
}

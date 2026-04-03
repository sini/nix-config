{ den, ... }:
{
  den.aspects.xserver = den.lib.perHost {
    nixos = {
      services = {
        libinput.enable = true;
        xserver = {
          enable = true;
          xkb = {
            layout = "us";
            variant = "";
          };
        };
      };
    };
  };
}

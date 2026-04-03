{ den, ... }:
{
  den.aspects.xwayland = den.lib.perHost {
    nixos = {
      programs.xwayland.enable = true;
    };
  };
}

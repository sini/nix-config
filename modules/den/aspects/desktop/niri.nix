{ den, ... }:
{
  # Note: niri requires uwsm aspect to be included by the host
  den.aspects.niri = den.lib.perHost {
    nixos = { };
  };
}

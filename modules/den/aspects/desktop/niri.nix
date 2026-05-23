{ den, ... }:
{
  den.aspects.desktop.niri = {
    includes = [ den.aspects.desktop.uwsm ];
    nixos = { };
  };
}

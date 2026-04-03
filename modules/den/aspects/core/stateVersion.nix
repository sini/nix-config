{ den, ... }:
{
  den.aspects.stateVersion = den.lib.perHost {
    darwin.system.stateVersion = "6";
    nixos.system.stateVersion = "26.05";
  };
}

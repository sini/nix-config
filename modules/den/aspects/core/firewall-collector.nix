{ den, ... }:
{
  den.aspects.core.firewall-collector = {
    nixos = { firewall, lib, ... }: lib.mkMerge firewall;
  };
}

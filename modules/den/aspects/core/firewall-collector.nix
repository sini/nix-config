_:
{
  den.aspects.core.firewall-collector = {
    nixos = { firewall, lib, ... }: lib.mkMerge firewall;
  };
}

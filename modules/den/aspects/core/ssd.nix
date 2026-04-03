{ den, ... }:
{
  den.aspects.ssd = den.lib.perHost {
    nixos.services.fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}

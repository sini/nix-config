# ssd — SSD fstrim service.
#
# Ported from main:modules/_legacy/core/ssd.nix.
_:
{
  den.aspects.core.ssd = {
    nixos = {
      services.fstrim = {
        enable = true;
        interval = "weekly";
      };
    };
  };
}

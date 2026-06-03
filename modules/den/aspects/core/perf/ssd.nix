# ssd — SSD fstrim service.
#
# Ported from main:modules/_legacy/core/ssd.nix.
{
  den.aspects.core.perf.ssd = {
    nixos = {
      services.fstrim = {
        enable = true;
        interval = "weekly";
      };
    };
  };
}

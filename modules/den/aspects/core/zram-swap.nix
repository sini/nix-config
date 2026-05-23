{ den, ... }:
{
  den.aspects.core.zram-swap = {
    nixos = {
      zramSwap.enable = true;

      # Prevent a single task from freezing the system without relying on the
      # kernel OOM killer's heuristics.
      services.earlyoom.enable = true;
      services.earlyoom.freeMemThreshold = 2;
    };
  };
}

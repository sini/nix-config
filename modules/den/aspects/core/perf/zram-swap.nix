{
  den.aspects.core.perf.zram-swap = {
    nixos = {
      zramSwap.enable = true;
      # zram pages are held in RAM, so the device is not spare capacity — it is
      # a claim on the same memory it is meant to relieve. At the stock 50% a
      # host under pressure swaps into its own remaining headroom. Keep the
      # device small enough that reclaiming into it is still a net win.
      zramSwap.memoryPercent = 25;

      # Prevent a single task from freezing the system without relying on the
      # kernel OOM killer's heuristics.
      services.earlyoom.enable = true;

      # earlyoom acts only when the memory AND the swap condition are both
      # satisfied. With zram as the only swap, free swap stays high precisely
      # when memory is exhausted, so the swap arm vetoes every kill and the
      # policy never fires. Pinning both swap arms at 100% makes that arm a
      # tautology and leaves the policy purely memory-driven, which is what it
      # was always meant to be. Hosts that gain a real disk swap should lower
      # these again rather than keep a condition that cannot discriminate.
      services.earlyoom.freeSwapThreshold = 100;
      services.earlyoom.freeSwapKillThreshold = 100;

      # Percentages of total RAM, so the same thresholds scale across a small
      # node and a large workstation. SIGTERM has to land while reclaim can
      # still make progress; by the time a few percent remain, direct reclaim
      # is already failing.
      services.earlyoom.freeMemThreshold = 5;
      services.earlyoom.freeMemKillThreshold = 2;
    };
  };
}

{
  flake.features.systemd-boot.nixos = {
    zramSwap.enable = true;

    # Ensure a single individual task doesn't freeze the system, without trusting the random action of the kernel
    # out-of-memory (OOM) killer.
    services.earlyoom.enable = true;
    services.earlyoom.freeMemThreshold = 2; # Percentage of total RAM
  };
}

{
  flake.features.performance.nixos =
    { pkgs, lib, ... }:
    {
      powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
      services.scx = {
        enable = true;
        package = lib.mkDefault pkgs.scx.full;
        scheduler = "scx_bpfland"; # Default is scx_rustland
        # Enable: CPU Frequency Control, (experimental) kthread prioritization, Per-CPU Task Prioritization
        extraArgs = [
          "-f"
          "-k"
          "-p"
        ];
      };
    };
}

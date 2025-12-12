{ inputs, ... }:
{
  flake.features.cpu-amd.nixos =
    { config, pkgs, ... }:
    {
      imports = [ inputs.ucodenix.nixosModules.default ];

      environment.systemPackages = [ pkgs.amdctl ];

      boot = {
        # blacklistedKernelModules = [ "k10temp" ];
        kernelModules = [
          "kvm-amd"
          "msr" # x86 CPU MSR access device
          # "zenpower"
        ];
        kernelParams = [
          # Ensure SMT (Simultaneous Multithreading) is enabled
          # If you see only 8 cores instead of 16 on a 9950X3D, check BIOS settings:
          # - Advanced > AMD CBS > CPU Common Options > Core/Thread Enablement > SMT Control = Auto/Enabled
          # - Advanced > AMD CBS > CPU Common Options > Core/Thread Enablement > Downcore Control = Disabled
          "smt=on"

          "microcode.amd_sha_check=off"
          "amd_iommu=on"
          "iommu=pt"

          "iomem=relaxed"
          "amd_pstate=guided" # power management
        ];
        # extraModulePackages = [ config.boot.kernelPackages.zenpower ];
      };

      services.ucodenix.enable = true;
      services.ucodenix.cpuModelId = config.facter.reportPath;
    };

}

{ inputs, ... }:
{
  flake.aspects.cpu-amd.nixos =
    { config, pkgs, ... }:
    {
      imports = [ inputs.ucodenix.nixosModules.default ];

      environment.systemPackages = [ pkgs.amdctl ];

      boot = {
        blacklistedKernelModules = [ "k10temp" ];
        kernelModules = [
          "kvm-amd"
          "msr" # x86 CPU MSR access device
          "zenpower"
        ];
        kernelParams = [
          "microcode.amd_sha_check=off"
          "amd_iommu=on"
          "iomem=relaxed"
          "amd_pstate=guided" # power management
        ];
        extraModulePackages = [ config.boot.kernelPackages.zenpower ];
      };

      services.ucodenix.enable = true;
      services.ucodenix.cpuModelId = config.facter.reportPath;
    };

}

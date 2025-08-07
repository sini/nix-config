{ inputs, ... }:
{
  flake.modules.nixos.cpu-amd =
    { config, pkgs, ... }:
    {
      imports = [ inputs.ucodenix.nixosModules.default ];

      environment.systemPackages = [ pkgs.amdctl ];

      boot = {
        kernelModules = [
          "kvm-amd"
          "amd-pstate" # load pstate module in case the device has a newer gpu
          "msr" # x86 CPU MSR access device
        ];
        kernelParams = [
          "microcode.amd_sha_check=off"
          "amd_iommu=on"
          "iomem=relaxed"
          "amd_pstate=guided" # power management
        ];
      };

      services.ucodenix.enable = true;
      services.ucodenix.cpuModelId = config.facter.reportPath;
    };

}

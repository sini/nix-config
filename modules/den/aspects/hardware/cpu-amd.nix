{ den, inputs, ... }:
{
  den.aspects.cpu-amd = den.lib.perHost {
    nixos =
      {
        config,
        pkgs,
        ...
      }:
      {
        imports = [ inputs.ucodenix.nixosModules.default ];

        environment.systemPackages = [ pkgs.amdctl ];

        boot = {
          kernelModules = [
            "kvm-amd"
            "msr" # x86 CPU MSR access device
          ];
          kernelParams = [
            # Ensure SMT (Simultaneous Multithreading) is enabled
            "smt=on"

            "microcode.amd_sha_check=off"
            "amd_iommu=on"
            "iommu=pt"

            "iomem=relaxed"
            "amd_pstate=active" # power management
          ];
        };

        services.ucodenix = {
          enable = true;
          cpuModelId = config.facter.reportPath;
        };
      };
  };
}

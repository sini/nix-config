{ inputs, ... }:
{
  den.aspects.hardware.cpu.amd = {
    nixos =
      { config, pkgs, ... }:
      {
        imports = [ inputs.ucodenix.nixosModules.default ];

        # ucodenix's package is missing jql from nativeBuildInputs
        nixpkgs.overlays = [
          (_final: prev: {
            ucodenix = prev.ucodenix.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.jql ];
            });
          })
        ];

        environment.systemPackages = [ pkgs.amdctl ];

        boot = {
          kernelModules = [
            "kvm-amd"
            "msr"
          ];
          kernelParams = [
            "smt=on"
            "microcode.amd_sha_check=off"
            "amd_iommu=on"
            "iommu=pt"
            "iomem=relaxed"
            "amd_pstate=active"
          ];
        };

        services.ucodenix.enable = true;
        services.ucodenix.cpuModelId = config.facter.reportPath;
      };
  };
}

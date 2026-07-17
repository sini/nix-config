{ inputs, ... }:
{
  den.aspects.hardware.cpu.amd = {
    # ucodenix's package is missing jql from nativeBuildInputs. Wrapped in a
    # function so the pipe assembly does not mistake the inline (positional)
    # overlay for a pipeline-parametric value and pre-apply it.
    nixpkgs-overlays = _: [
      (_final: prev: {
        ucodenix = prev.ucodenix.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.jql ];
        });
      })
    ];

    nixos =
      { config, pkgs, ... }:
      {
        imports = [ inputs.ucodenix.nixosModules.default ];

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

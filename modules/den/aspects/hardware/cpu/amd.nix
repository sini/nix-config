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

        # amd_pstate=active hands frequency selection to the firmware via EPP
        # and offers only performance|powersave, so the schedutil/ondemand
        # defaults other aspects request are dropped without a warning and the
        # host silently lands on powersave anyway. State the reachable governor
        # where the restriction originates; a plain assignment outranks their
        # mkDefault. Anything wanting a governor-driven policy (including
        # scx's --cpufreq) has to move this host off active mode first.
        powerManagement.cpuFreqGovernor = "powersave";

        services.ucodenix.enable = true;
        services.ucodenix.cpuModelId = config.facter.reportPath;
      };
  };
}

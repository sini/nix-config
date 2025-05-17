{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (lib.modules) mkIf;
  cpuType = (builtins.head config.facter.report.hardware.cpu).vendor_name;
in
{
  imports = [ inputs.ucodenix.nixosModules.default ];
  config = mkIf (cpuType == "AuthenticAMD") {
    environment.systemPackages = [ pkgs.amdctl ];

    boot = {
      kernelModules = [
        "kvm-amd"
        "amd-pstate" # load pstate module in case the device has a newer gpu
        "zenpower" # zenpower is for reading cpu info, i.e voltage
        "msr" # x86 CPU MSR access device
      ];
      kernelParams = [
        "microcode.amd_sha_check=off"
        "amd_iommu=on"
        "amd_pstate=guided" # power management
      ];
      extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    };

    services.ucodenix = {
      enable = true;
      cpuModelId = config.facter.reportPath;
    };
  };
}

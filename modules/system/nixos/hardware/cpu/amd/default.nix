{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.modules) mkIf;
  cpuType = (builtins.head config.facter.report.hardware.cpu).vendor_name;
in
{
  config = mkIf (cpuType == "AuthenticAMD") {
    environment.systemPackages = [ pkgs.amdctl ];

    hardware.cpu.amd.updateMicrocode = true;
    boot = {
      kernelModules = [
        "kvm-amd"
        "amd-pstate" # load pstate module in case the device has a newer gpu
        # "zenpower" # zenpower is for reading cpu info, i.e voltage
        "msr" # x86 CPU MSR access device
      ];
      kernelParams = [ "amd_iommu=on" ];
      #extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    };
  };
}

{
  config,
  lib,
  ...
}:
let
  inherit (lib.modules) mkIf;
  cpuType = (builtins.head config.facter.report.hardware.cpu).vendor_name;
in
{
  config = mkIf (cpuType == "GenuineIntel") {
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}

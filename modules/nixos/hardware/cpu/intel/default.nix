{
  config,
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
  config = mkIf (cpuType == "Intel") {
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    services.ucodenix = {
      enable = true;
      cpuModelId = config.facter.reportPath;
    };
  };
}

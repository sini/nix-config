{
  flake.modules.nixos.firmware = {
    hardware.enableRedistributableFirmware = true;
    hardware.enableAllFirmware = true;
    services.fwupd = {
      enable = true;
    };
  };
}

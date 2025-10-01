{
  flake.aspects.firmware.nixos = {
    hardware.enableRedistributableFirmware = true;
    hardware.enableAllFirmware = true;
    services.fwupd = {
      enable = true;
    };
  };
}

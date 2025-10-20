{
  flake.features.firmware.nixos = {
    hardware.enableRedistributableFirmware = true;
    hardware.enableAllFirmware = true;
    services.fwupd = {
      enable = true;
    };
    environment.persistence."/persist".directories = [
      "/var/cache/fwupd"
      "/var/lib/fwupd"
    ];
  };
}

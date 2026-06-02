_: {
  den.aspects.core.system.firmware = {
    nixos = {
      hardware.enableRedistributableFirmware = true;
      hardware.enableAllFirmware = true;

      services.fwupd.enable = true;
    };

    persist = {
      directories = [
        "/var/cache/fwupd"
        "/var/lib/fwupd"
      ];
    };
  };
}

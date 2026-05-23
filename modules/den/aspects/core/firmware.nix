_:
{
  den.aspects.core.firmware = {
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

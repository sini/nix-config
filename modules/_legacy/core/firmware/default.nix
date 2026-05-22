{
  features.firmware = {
    linux = {
      hardware.enableRedistributableFirmware = true;
      hardware.enableAllFirmware = true;

      services.fwupd = {
        enable = true;
      };

      impermanence.ignorePaths = [
        "/etc/fwupd/fwupd.conf"
      ];
    };

    provides.impermanence.linux = {
      environment.persistence."/persist".directories = [
        "/var/cache/fwupd"
        "/var/lib/fwupd"
      ];
    };
  };
}

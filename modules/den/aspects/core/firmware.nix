{ den, lib, ... }:
{
  den.aspects.firmware = {
    includes = lib.attrValues den.aspects.firmware._;

    _ = {
      config = den.lib.perHost {
        nixos = {
          hardware.enableRedistributableFirmware = true;
          hardware.enableAllFirmware = true;

          services.fwupd = {
            enable = true;
          };
        };
      };

      impermanence = den.lib.perHost {
        nixos.environment.persistence."/persist".directories = [
          "/var/cache/fwupd"
          "/var/lib/fwupd"
        ];
      };
    };
  };
}

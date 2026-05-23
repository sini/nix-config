_:
{
  den.aspects.hardware.ddcutil = {
    nixos =
      { config, pkgs, ... }:
      {
        boot = {
          kernelModules = [
            "i2c-dev"
          ];
          initrd.availableKernelModules = [
            "i2c-dev"
          ];
          extraModulePackages = [
            config.boot.kernelPackages.ddcci-driver
          ];
        };

        environment.systemPackages = [
          pkgs.ddcutil
        ];

        services.udev.packages = [
          pkgs.ddcutil
        ];

        users.groups.i2c = { };
      };
  };
}

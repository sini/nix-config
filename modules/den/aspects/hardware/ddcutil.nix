{ lib, ... }:
{
  den.aspects.hardware.ddcutil = {
    nixos =
      {
        config,
        pkgs,
        host,
        ...
      }:
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

        users.users = lib.genAttrs (builtins.attrNames host.users) (_: {
          extraGroups = [ "i2c" ];
        });
      };
  };
}

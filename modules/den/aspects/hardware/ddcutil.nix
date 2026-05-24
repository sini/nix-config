{ lib, ... }:
{
  den.aspects.hardware.ddcutil = {
    nixos =
      {
        config,
        pkgs,
        resolved-users,
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

        users.users = lib.genAttrs (map (u: u.name) resolved-users) (_: {
          extraGroups = [ "i2c" ];
        });
      };
  };
}

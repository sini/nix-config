{
  flake.features.ddcutil.nixos =
    { config, pkgs, ... }:
    {
      imports = [
        (
          { lib, ... }:
          {
            options.users.users = lib.mkOption {
              type =
                with lib.types;
                attrsOf (
                  submodule (
                    { config, ... }:
                    {
                      options = { };
                      config.extraGroups = lib.optionals config.isNormalUser [ "i2c" ];
                    }
                  )
                );
            };
          }
        )
      ];

      boot = {
        kernelModules = [
          "i2c-dev"
        ];
        initrd.availableKernelModules = [
          "i2c-dev"
        ];
        extraModulePackages = with config.boot.kernelPackages; [
          ddcci-driver
        ];
      };

      environment.systemPackages = with pkgs; [
        ddcutil
      ];

      services.udev.packages = with pkgs; [
        ddcutil
      ];
    };
}

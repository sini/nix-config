_: {
  den.aspects.hardware.gamepad = {
    nixos =
      { pkgs, config, ... }:
      {
        hardware = {
          uinput.enable = true;
          xone.enable = true;
          xpadneo.enable = true;
        };

        boot = {
          extraModulePackages = [
            config.boot.kernelPackages.xpadneo
          ];
          extraModprobeConfig = ''
            options bluetooth disable_ertm=Y
          '';
          kernelModules = [
            "hid_microsoft"
          ];
        };

        services.udev.packages = [
          pkgs.game-devices-udev-rules
        ];
      };
  };
}

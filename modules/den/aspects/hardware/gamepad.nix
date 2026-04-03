{ den, ... }:
{
  den.aspects.gamepad = den.lib.perHost {
    nixos =
      {
        pkgs,
        config,
        ...
      }:
      {
        hardware = {
          uinput.enable = true;
          xone.enable = true;
          xpadneo.enable = true;
        };

        boot = {
          extraModulePackages = with config.boot.kernelPackages; [
            xpadneo
          ];
          extraModprobeConfig = ''
            options bluetooth disable_ertm=Y
          '';
          kernelModules = [
            "hid_microsoft"
          ];
        };

        services = {
          udev = {
            packages = with pkgs; [
              game-devices-udev-rules
            ];
          };
        };
      };
  };
}

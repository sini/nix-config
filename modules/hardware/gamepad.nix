{
  flake.features.gamepad.nixos =
    {
      pkgs,
      ...
    }:
    {
      hardware = {
        uinput.enable = true;
        # TODO: https://github.com/NixOS/nixpkgs/issues/467164
        # xone.enable = true; # support for the xbox controller USB dongle
        # xpadneo.enable = true; # Enable the xpadneo driver for Xbox One wireless controllers
      };

      boot = {
        # TODO: https://github.com/NixOS/nixpkgs/issues/467164
        # extraModulePackages = with config.boot.kernelPackages; [
        #   xpadneo # xbox
        # ];
        extraModprobeConfig = ''
          options bluetooth disable_ertm=Y
        ''; # connect xbox controller
        kernelModules = [
          "hid_microsoft" # Xbox One Elite 2 controller driver preferred by Steam
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

}

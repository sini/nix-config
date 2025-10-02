{
  flake.features.gamepad.nixos =
    {
      config,
      pkgs,
      ...
    }:
    {
      hardware = {
        uinput.enable = true;
        xone.enable = true; # support for the xbox controller USB dongle
        xpadneo.enable = true; # Enable the xpadneo driver for Xbox One wireless controllers

      };

      boot = {
        extraModulePackages = with config.boot.kernelPackages; [
          xpadneo # xbox
        ];
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

      # See: https://gist.github.com/interdependence/28452fbfbe692986934fbe1e54c920d4
      #   udev.extraRules = ''
      #     # Custom lines lifted from: https://gist.github.com/interdependence/28452fbfbe692986934fbe1e54c920d4
      #     # 8bitdo Ultimate C wireless controller
      #     # May vary depending on your controller model, find product id using 'lsusb'
      #     SUBSYSTEM=="usb", ATTR{idVendor}=="2dc8", ATTR{idProduct}=="3106", ATTR{manufacturer}=="8BitDo", RUN+="${pkgs.systemd}/bin/systemctl start 8bitdo-ultimate-xinput@2dc8:3106"
      #     # This device (2dc8:3016) is "connected" when the above device disconnects
      #     SUBSYSTEM=="usb", ATTR{idVendor}=="2dc8", ATTR{idProduct}=="3016", ATTR{manufacturer}=="8BitDo", RUN+="${pkgs.systemd}/bin/systemctl stop 8bitdo-ultimate-xinput@2dc8:3106"
      #     # 8bitdo Ultimate 2C wireless controller
      #     SUBSYSTEM=="usb", ATTR{idVendor}=="2dc8", ATTR{idProduct}=="310a", ATTR{manufacturer}=="8BitDo", RUN+="${pkgs.systemd}/bin/systemctl start 8bitdo-ultimate-xinput@2dc8:310a"
      #     # This device (2dc8:3016) is "connected" when the above device disconnects
      #     SUBSYSTEM=="usb", ATTR{idVendor}=="2dc8", ATTR{idProduct}=="301a", ATTR{manufacturer}=="8BitDo", RUN+="${pkgs.systemd}/bin/systemctl stop 8bitdo-ultimate-xinput@2dc8:310a"
      #   '';
      # };

      #   # Systemd service which starts xboxdrv in xbox360 mode
      #   systemd.services."8bitdo-ultimate-xinput@" = {
      #     unitConfig.Description = "8BitDo Ultimate Controller XInput mode xboxdrv daemon";
      #     serviceConfig = {
      #       Type = "simple";
      #       ExecStart = "${pkgs.xboxdrv}/bin/xboxdrv --mimic-xpad --silent --type xbox360 --device-by-id %I --force-feedback";
      #     };
      #   };

    };

}

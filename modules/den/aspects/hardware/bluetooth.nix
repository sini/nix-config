{
  den.aspects.hardware.bluetooth = {
    nixos =
      { pkgs, ... }:
      {
        hardware.bluetooth = {
          enable = true;
          package = pkgs.bluez-experimental;
          powerOnBoot = true;
          disabledPlugins = [ "sap" ];
          settings = {
            Policy.AutoEnable = true;
            General = {
              Privacy = "device";
              FastConnectable = true;
              Experimental = true;
              KernelExperimental = true;
              JustWorksRepairing = "always";
              MultiProfile = "multiple";
              Class = "0x000100";
              Enable = "Source,Sink,Media,Socket";
            };
          };
        };

        boot.kernelParams = [ "btusb" ];

        services.blueman.enable = true;
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.bluetui
        ];
      };

    persist = {
      directories = [
        "/var/lib/bluetooth"
      ];
    };
  };
}

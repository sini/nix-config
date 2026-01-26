{
  flake.features.bluetooth = {
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
              Class = "0x000100"; # Computer class
              # Class = 0x100100 # (Object-Transfer Service & Computer Type)
              Enable = "Source,Sink,Media,Socket";
            };
          };
        };

        boot.kernelParams = [ "btusb" ];

        services.blueman.enable = true;

        environment.persistence."/cache".directories = [ "/var/lib/bluetooth" ];
      };

    home =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.bluetui
        ];
      };
  };
}

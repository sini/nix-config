{ den, lib, ... }:
{
  den.aspects.bluetooth = {
    includes = lib.attrValues den.aspects.bluetooth._;

    _ = {
      config = den.lib.perHost {
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
      };

      home = den.lib.perUser {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = [
              pkgs.bluetui
            ];
          };
      };

      impermanence = den.lib.perHost {
        nixos = {
          environment.persistence."/cache".directories = [ "/var/lib/bluetooth" ];
        };
      };
    };
  };
}

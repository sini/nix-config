{
  flake.features.bluetooth.nixos =
    { pkgs, ... }:
    {
      # environment.persistence."/persist/system" = lib.mkIf isImpermanent {
      #   directories = [
      #     "/var/lib/bluetooth"
      #   ];
      # };

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

      # services.pulseaudio = {
      #   package = pkgs.pulseaudio.override { bluetoothSupport = true; };
      #   extraConfig = ''
      #     load-module module-bluetooth-discover
      #     load-module module-bluetooth-policy
      #     load-module module-switch-on-connect
      #   '';
      #   extraModules = with pkgs; [ pulseaudio-modules-bt ];
      # };

      environment.persistence."/cache".directories = [ "/var/lib/bluetooth" ];
    };
}

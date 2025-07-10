{
  flake.modules.nixos.bluetooth =
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
            FastConnectable = true;
            Experimental = true;
            KernelExperimental = true;
            JustWorksRepairing = "always";
            MultiProfile = "multiple";
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
    };
}

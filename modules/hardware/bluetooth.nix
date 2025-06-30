{
  flake.modules.nixos.bluetooth =
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
            FastConnectable = true;
            Experimental = true;
            KernelExperimental = true;
            JustWorksRepairing = "always";
            MultiProfile = "multiple";
            Enable = "Source,Sink,Media,Socket";

            # # Enable device auto-reconnection
            # AutoEnable = cfg.autoConnect;
            # ReconnectAttempts = if cfg.autoConnect then 7 else 0;
            # ReconnectIntervals = "1,2,4,8,16,32,64";
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

{
  flake.modules.nixos.laptop =
    { pkgs, lib, ... }:
    {
      environment.systemPackages = with pkgs; [
        brightnessctl
      ];

      powerManagement = {
        # powertop = {
        #   enable = true;
        #   postStart = [
        #     # disable USB auto suspend for Razer Deathadder and Pulsar x2 mice
        #     "${lib.getExe' config.systemd.package "udevadm"} trigger -c bind -s usb -a idVendor=25a7 -a idProduct=fa7c"
        #     "${lib.getExe' config.systemd.package "udevadm"} trigger -c bind -s usb -a idVendor=1532 -a idProduct=00b2"
        #   ];
        # };
        cpuFreqGovernor = lib.mkDefault "schedutil";
      };

      services = {
        power-profiles-daemon.enable = false; # Disable GNOMEs power management

        # system76-scheduler = {
        #   enable = true;
        #   useStockConfig = true;
        #   # https://search.nixos.org/options?channel=unstable&show=services.system76-scheduler
        #   settings.processScheduler.foregroundBoost.enable = true;
        #   settings.cfsProfiles.enable = true;
        # };

        # auto-cpufreq = {
        #   enable = true;
        #   settings = {
        #     battery = {
        #       governor = "powersave";
        #       turbo = "never";
        #     };
        #     charger = {
        #       governor = "powersave";
        #       turbo = "auto";
        #     };
        #   };
        # };

        # Only required on intel...
        thermald.enable = true;

        # udev.extraRules = ''
        #   # disable USB auto suspend for Razer Deathadder and Pulsar x2 mice
        #   ACTION=="bind", SUBSYSTEM=="usb", ATTR{idVendor}=="25a7", ATTR{idProduct}=="fa7c", TEST=="power/control", ATTR{power/control}="on"
        #   ACTION=="bind", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="00b2", TEST=="power/control", ATTR{power/control}="on"
        # '';
      };
    };
}

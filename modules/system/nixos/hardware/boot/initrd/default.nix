_: {
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        consoleMode = "0"; # increase font size
      };

      efi.canTouchEfiVariables = true;
    };

    initrd = {
      systemd.enable = true;
      verbose = false;
    };

    tmp.cleanOnBoot = true;

    kernelParams = [
      # For AMD Zen 4 this is no longer needed: https://www.phoronix.com/news/AMD-Zen-4-Mitigations-Off
      "mitigations=off"
      "quiet"
      "udev.log_level=3"
      "ip=dhcp"
    ];

    plymouth.enable = true; # Display loading screen

    consoleLogLevel = 0;
  };
}

_: {
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "0"; # increase font size
      };

      efi.canTouchEfiVariables = true;
    };

    tmp.cleanOnBoot = true;

    kernelParams = [
      # For AMD Zen 4 this is no longer needed: https://www.phoronix.com/news/AMD-Zen-4-Mitigations-Off
      "mitigations=off"
      "quiet"
      "udev.log_level=3"
    ];

    plymouth.enable = true; # Display loading screen

    initrd = {
      systemd.enable = true;
      verbose = false;
    };

    consoleLogLevel = 0;

  };
}

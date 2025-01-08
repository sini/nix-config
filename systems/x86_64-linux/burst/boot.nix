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
      luks.devices."luks-defb6e58-f883-4c98-b933-5d62f344bb9b".device =
        "/dev/disk/by-uuid/defb6e58-f883-4c98-b933-5d62f344bb9b";
    };

    consoleLogLevel = 0;

  };
}

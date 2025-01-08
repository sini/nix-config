_: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.consoleMode = "0"; # increase font size
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.cleanOnBoot = true;

  boot.kernelParams = [
    # For AMD Zen 4 this is no longer needed: https://www.phoronix.com/news/AMD-Zen-4-Mitigations-Off
    "mitigations=off"
    "quiet"
    "udev.log_level=3"
  ];

  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true; # Display loading screen

  boot.initrd.verbose = false;
  boot.consoleLogLevel = 0;

  boot.initrd.luks.devices."luks-defb6e58-f883-4c98-b933-5d62f344bb9b".device =
    "/dev/disk/by-uuid/defb6e58-f883-4c98-b933-5d62f344bb9b";
}

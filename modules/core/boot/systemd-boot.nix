{
  flake.aspects.systemd-boot.nixos = {
    boot = {
      initrd.systemd.enable = true;

      loader = {
        systemd-boot = {
          enable = true;
          configurationLimit = 10;
          consoleMode = "0"; # increase font size
        };

        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot";
        };
      };

      kernelParams = [
        # For AMD Zen 4 this is no longer needed: https://www.phoronix.com/news/AMD-Zen-4-Mitigations-Off
        "mitigations=off"
      ];
    };
  };
}

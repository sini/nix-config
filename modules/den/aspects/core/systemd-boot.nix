# Boot configuration: systemd-boot, tmpfs, zram swap, earlyoom
{ den, ... }:
{
  den.aspects.systemd-boot = den.lib.perHost {
    nixos = {
      boot = {
        initrd = {
          compressor = "zstd";
          compressorArgs = [ "-12" ];
          systemd.enable = true;
        };

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
          "mitigations=off"
        ];

        # tmpfs for /tmp
        tmp = {
          useTmpfs = true;
          cleanOnBoot = true;
        };
      };

      # zram swap
      zramSwap.enable = true;

      # OOM prevention - kill before freeze
      services.earlyoom = {
        enable = true;
        freeMemThreshold = 2; # percentage of total RAM
      };
    };
  };
}

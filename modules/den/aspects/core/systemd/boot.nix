{
  den.aspects.core.systemd.boot = {
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
            configurationLimit = 5;
            consoleMode = "0";
          };
          efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot";
          };
        };

        kernelParams = [
          "mitigations=off"
        ];
      };
    };
  };
}

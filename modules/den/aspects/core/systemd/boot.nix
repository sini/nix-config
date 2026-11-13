{
  den.aspects.core.systemd.boot = {
    nixos =
      { lib, ... }:
      {
        boot = {
          initrd = {
            compressor = "zstd";
            compressorArgs = [ "-12" ];
          };

          loader = {
            systemd-boot = {
              enable = true;
              configurationLimit = lib.mkDefault 5;
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

{
  flake.features.gpu-nvidia-driver.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      boot = {

        kernelParams = [
          "nvidia-drm.modeset=1"
          "nvidia-drm.fbdev=1"
        ];

        extraModprobeConfig =
          "options nvidia "
          + lib.concatStringsSep " " [
            # nvidia assume that by default your CPU does not support PAT,
            # but this is effectively never the case in 2023
            "NVreg_UsePageAttributeTable=1"
            "nvidia.NVreg_EnableGpuFirmware=1"
            # This is sometimes needed for ddc/ci support, see
            # https://www.ddcutil.com/nvidia/
            #
            # Current monitor does not support it, but this is useful for
            # the future
            "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
          ];
      };

      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          libva-vdpau-driver
          libvdpau
          libvdpau-va-gl
          nvidia-vaapi-driver
          vdpauinfo
          libva
          libva-utils
        ];
      };

      hardware.nvidia = {
        forceFullCompositionPipeline = true;
        modesetting.enable = true;
        powerManagement.enable = true;
        open = true;
        nvidiaSettings = false;
        nvidiaPersistenced = true;
        # package = config.boot.kernelPackages.nvidiaPackages.beta;
        #TODO:
        package =
          let
            fixPatch = pkgs.fetchpatch {
              url = "https://raw.githubusercontent.com/CachyOS/kernel-patches/master/6.19/misc/nvidia/0003-Fix-compile-for-6.19.patch";
              hash = "sha256-YuJjSUXE6jYSuZySYGnWSNG5sfVei7vvxDcHx3K+IN4=";
            };
            base = config.boot.kernelPackages.nvidiaPackages.latest;
          in
          base
          // {
            open = base.open.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ fixPatch ];
            });
          };
      };
    };

}

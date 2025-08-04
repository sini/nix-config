{
  flake.modules.nixos.gpu-nvidia =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    with lib;
    with lib.custom;
    let
      # TODO: use the latest beta version
      nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "575.64.05";
        sha256_64bit = "sha256-hfK1D5EiYcGRegss9+H5dDr/0Aj9wPIJ9NVWP3dNUC0=";
        sha256_aarch64 = "sha256-GRE9VEEosbY7TL4HPFoyo0Ac5jgBHsZg9sBKJ4BLhsA=";
        openSha256 = "sha256-mcbMVEyRxNyRrohgwWNylu45vIqF+flKHnmt47R//KU=";
        settingsSha256 = "sha256-o2zUnYFUQjHOcCrB0w/4L6xI1hVUXLAWgG2Y26BowBE=";
        persistencedSha256 = "sha256-2g5z7Pu8u2EiAh5givP5Q1Y4zk4Cbb06W37rf768NFU=";

        patches = [ gpl_symbols_linux_615_patch ];
      };

      gpl_symbols_linux_615_patch = pkgs.fetchpatch {
        url = "https://github.com/CachyOS/kernel-patches/raw/914aea4298e3744beddad09f3d2773d71839b182/6.15/misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch";
        hash = "sha256-YOTAvONchPPSVDP9eJ9236pAPtxYK5nAePNtm2dlvb4=";
        stripLen = 1;
        extraPrefix = "kernel/";
      };
    in
    {
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          vaapiVdpau
          libvdpau
          libvdpau-va-gl
          nvidia-vaapi-driver
          vdpauinfo
          libva
          libva-utils
        ];
      };

      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        forceFullCompositionPipeline = true;
        modesetting.enable = true;
        powerManagement.enable = true;
        open = true;
        nvidiaSettings = false;
        nvidiaPersistenced = true;
        package = nvidiaPackage;
      };

      boot = {
        kernelModules = [
          "nvidia"
          "nvidia_modeset"
          "nvidia_drm"
          "nvidia_uvm"
        ];

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

      environment = {
        systemPackages = with pkgs; [
          lact # GUI for overclocking, undervolting, setting fan curves, etc.
          pciutils
          nvtopPackages.full
          libva-utils
          gwe
          vulkan-tools
          mesa-demos
          zenith-nvidia
          nvitop
          vulkanPackages_latest.vulkan-loader
          vulkanPackages_latest.vulkan-validation-layers
          vulkanPackages_latest.vulkan-tools
        ];

        variables = {
          # Required to run the correct GBM backend for nvidia GPUs on wayland
          GBM_BACKEND = "nvidia-drm";
          # Apparently, without this nouveau may attempt to be used instead
          # (despite it being blacklisted)
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          # Hardware cursors are currently broken on wlroots
          WLR_NO_HARDWARE_CURSORS = "1";
        };
      };
    };

}

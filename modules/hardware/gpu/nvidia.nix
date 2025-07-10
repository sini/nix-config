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
      #nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.beta;
      # TODO: use the latest beta version
      nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "575.57.08";
        sha256_64bit = "sha256-KqcB2sGAp7IKbleMzNkB3tjUTlfWBYDwj50o3R//xvI=";
        sha256_aarch64 = "sha256-VJ5z5PdAL2YnXuZltuOirl179XKWt0O4JNcT8gUgO98=";
        openSha256 = "sha256-DOJw73sjhQoy+5R0GHGnUddE6xaXb/z/Ihq3BKBf+lg=";
        settingsSha256 = "sha256-AIeeDXFEo9VEKCgXnY3QvrW5iWZeIVg4LBCeRtMs5Io=";
        persistencedSha256 = "sha256-Len7Va4HYp5r3wMpAhL4VsPu5S0JOshPFywbO7vYnGo=";

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
        powerManagement.finegrained = true;
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

# Based on https://github.com/TLATER/dotfiles/blob/master/nixos-modules/nvidia/prime.nix
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
  cfg = config.hardware.gpu.nvidia;
in
{
  options.hardware.gpu.nvidia = with types; {
    enable = mkBoolOpt false "Enable NVIDIA GPU support";
    withIntegratedGPU = mkBoolOpt false "Use NVIDIA GPU with integrated GPU (e.g. Intel)";
    intelBusID = mkOption {
      type = types.str;
      default = "PCI:0:2:0";
    };
    nvidiaBusID = mkOption {
      type = types.str;
      default = "PCI:1:0:0";
    };
  };

  config = mkIf cfg.enable {

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
      prime = mkIf cfg.withIntegratedGPU {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = cfg.intelBusID;
        nvidiaBusId = cfg.nvidiaBusID;
      };
      forceFullCompositionPipeline = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      open = true;
      nvidiaSettings = false;
      package = nvidiaPackage;
      dynamicBoost.enable = cfg.enable && cfg.withIntegratedGPU;
    };

    # Set up a udev rule to create named symlinks for the pci paths.
    #
    # This is necessary because wlroots splits the DRM_DEVICES on
    # `:`, which is part of the pci path.
    services.udev.packages =
      let
        pciPath =
          xorgBusId:
          let
            components = lib.drop 1 (lib.splitString ":" xorgBusId);
            toHex = i: lib.toLower (lib.toHexString (lib.toInt i));

            domain = "0000"; # Apparently the domain is practically always set to 0000
            bus = lib.fixedWidthString 2 "0" (toHex (builtins.elemAt components 0));
            device = lib.fixedWidthString 2 "0" (toHex (builtins.elemAt components 1));
            function = builtins.elemAt components 2; # The function is supposedly a decimal number
          in
          "dri/by-path/pci-${domain}:${bus}:${device}.${function}-card";

        pCfg = config.hardware.nvidia.prime;
        igpuPath = pciPath (if pCfg.intelBusId != "" then pCfg.intelBusId else pCfg.amdgpuBusId);
        dgpuPath = pciPath pCfg.nvidiaBusId;
      in
      lib.mkIf cfg.withIntegratedGPU (
        lib.singleton (
          pkgs.writeTextDir "lib/udev/rules.d/61-gpu-offload.rules" ''
            SYMLINK=="${igpuPath}", SYMLINK+="dri/igpu1"
            SYMLINK=="${dgpuPath}", SYMLINK+="dri/dgpu1"
          ''
        )
      );

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
        nvtopPackages.nvidia
        libva-utils
        gwe
        vulkan-tools
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

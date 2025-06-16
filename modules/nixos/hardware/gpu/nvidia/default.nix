# Based on https://github.com/akirak/homelab/blob/master/profiles/intel-arc/default.nix
# Which was based on https://github.com/VTimofeenko/monorepo-machine-config/blob/4c1f85c700c45a5d3a8a38956194d2c97753b8ba/nixosConfigurations/neon/configuration/hw-acceleration.nix#L24
{
  config,
  lib,
  ...
}:
with lib;
with lib.custom;
let
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
        vaapiVdpau
        nvidia-vaapi-driver
      ];
    };

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      prime = mkIf cfg.withIntegratedGPU {
        enable = true;
        offload.enable = true;
        intelBusId = cfg.intelBusID;
        nvidiaBusId = cfg.nvidiaBusID;
      };
      forceFullCompositionPipeline = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      open = true;
      nvidiaSettings = false;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      dynamicBoost.enable = cfg.enable && cfg.withIntegratedGPU;
    };

    boot = {
      extraModprobeConfig =
        "options nvidia "
        + lib.concatStringsSep " " [
          # nvidia assume that by default your CPU does not support PAT,
          # but this is effectively never the case in 2023
          "NVreg_UsePageAttributeTable=1"
          # This is sometimes needed for ddc/ci support, see
          # https://www.ddcutil.com/nvidia/
          #
          # Current monitor does not support it, but this is useful for
          # the future
          "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
        ];
    };
    environment = {
      systemPackages = [ pkgs.libva-utils ];

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

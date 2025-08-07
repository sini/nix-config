{
  flake.modules.nixos.gpu-intel =
    { pkgs, ... }:
    {
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-ocl
          vpl-gpu-rt
          intel-compute-runtime
          intel-vaapi-driver
          libvdpau-va-gl
        ];
      };

      boot.kernelParams = [
        "i915.enable_guc=3"
      ];

      environment.sessionVariables = {
        VDPAU_DRIVER = "va_gl";
        LIBVA_DRIVER_NAME = "iHD";
        LIBVA_DRIVERS_PATH = "${pkgs.intel-media-driver}/lib/dri";
      };

      environment.systemPackages = with pkgs; [
        pciutils
        intel-gpu-tools
        nvtopPackages.full
        mesa-demos
        vulkanPackages_latest.vulkan-loader
        vulkanPackages_latest.vulkan-validation-layers
        vulkanPackages_latest.vulkan-tools
        libva-utils
      ];
    };
}

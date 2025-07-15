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
        ];
      };

      boot.kernelParams = [
        "i915.enable_guc=3"
      ];

      environment.sessionVariables = {
        VDPAU_DRIVER = "va_gl";
        LIBVA_DRIVER_NAME = "iHD";
      };

      environment.systemPackages = with pkgs; [
        pciutils
        libva-utils
        intel-gpu-tools
        nvtopPackages.full
        mesa-demos
        vulkan-tools
      ];
    };
}

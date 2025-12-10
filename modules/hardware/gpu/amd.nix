{
  flake.features.gpu-amd.nixos =
    { pkgs, ... }:
    {
      # Allow for overclocking
      boot.kernelParams = [
        "amdgpu.dc=1"
        "amdgpu.powerplay=1"
        "amdgpu.ppfeaturemask=0xffffffff"
        "radeon.modeset=0"
      ];

      boot.kernelModules = [
        "amdgpu"
        "radeon"
      ];
      services.xserver.videoDrivers = [ "amdgpu" ];

      hardware = {
        amdgpu = {
          opencl.enable = true;
          initrd.enable = true;
          overdrive.enable = true;
        };

        graphics = {
          enable = true;
          enable32Bit = true;
          extraPackages = with pkgs; [
            libva-vdpau-driver
            libva
            libvdpau-va-gl
            vulkan-tools
            vulkan-loader
            vulkan-validation-layers
            vulkan-extension-layer
            rocmPackages.clr.icd
          ];
        };

      };

      nixpkgs.config.rocmSupport = true;

      # WARNING: It will break NVIDIA's libgbm, don't use with NVIDIA Optimus setups.
      # chaotic.mesa-git = {
      #   enable = true;
      #   fallbackSpecialisation = false;
      # };

      # Enable HDR support
      # chaotic.hdr = {
      #   enable = true;
      #   specialisation.enable = false;
      # };

      # environment.variables = {
      #   AMD_VULKAN_ICD = "RADV"; # Force RADV when amdvlk is enabled
      #   # NOTE: nixos manual says you can also use radeon_icd.json to force radv, here's the values for amdvlk for reference
      #   VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json";
      #   VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json";
      #   LIBVA_DRIVER_NAME = "radeonsi";

      #   # Make gnome use the AMD driver....
      #   __GLX_VENDOR_LIBRARY_NAME = "mesa";
      #   __EGL_VENDOR_LIBRARY_FILENAMES = "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json";
      #   LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib:${pkgs.mesa}/lib/dri";
      #   #WLR_DRM_DEVICES = "/dev/dri/card0";
      # };

      environment.systemPackages = with pkgs; [
        lact # GUI for overclocking, undervolting, setting fan curves, etc.
        pciutils
        rocmPackages.rocminfo
        clinfo
        nvtopPackages.amd
        amdgpu_top
        vulkan-tools
        vulkan-loader
        vulkan-validation-layers
        vulkan-extension-layer
        libva-utils
        mesa-demos
      ];

      # GPU overclocking/undervolting daemon
      systemd.packages = with pkgs; [ lact ];
      systemd.services.lactd.wantedBy = [ "multi-user.target" ];

    };
}

_: {
  den.aspects.hardware.gpu-amd = {
    nixos =
      { pkgs, ... }:
      {
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
            extraPackages = [
              pkgs.libva-vdpau-driver
              pkgs.libva
              pkgs.libvdpau-va-gl
              pkgs.vulkan-tools
              pkgs.vulkan-loader
              pkgs.vulkan-validation-layers
              pkgs.vulkan-extension-layer
              pkgs.rocmPackages.clr.icd
            ];
          };
        };

        # nixpkgs.config.rocmSupport = true; # TODO: Restore ROCM

        environment.systemPackages = [
          pkgs.lact
          pkgs.pciutils
          pkgs.rocmPackages.rocminfo
          pkgs.clinfo
          pkgs.nvtopPackages.amd
          pkgs.amdgpu_top
          pkgs.vulkan-tools
          pkgs.vulkan-loader
          pkgs.vulkan-validation-layers
          pkgs.vulkan-extension-layer
          pkgs.libva-utils
          pkgs.mesa-demos
        ];

        # GPU overclocking/undervolting daemon
        systemd.packages = [ pkgs.lact ];
        systemd.services.lactd.wantedBy = [ "multi-user.target" ];
      };
  };
}

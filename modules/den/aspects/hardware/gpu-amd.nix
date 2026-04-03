{ den, ... }:
{
  den.aspects.gpu-amd = den.lib.perHost {
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

        environment.systemPackages = with pkgs; [
          lact
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
  };
}

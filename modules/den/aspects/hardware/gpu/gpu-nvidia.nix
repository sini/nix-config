{ den, lib, ... }:
{
  # Note: original feature requires gpu-nvidia-driver and gpu-nvidia-kernel.
  # In den, host includes handle dependencies — include all nvidia sub-aspects.
  den.aspects.gpu-nvidia = {
    includes = lib.attrValues den.aspects.gpu-nvidia._;

    _ = {
      config = den.lib.perHost {
        nixos =
          { pkgs, ... }:
          {
            nix.settings = {
              substituters = [
                "https://cuda-maintainers.cachix.org"
              ];
              trusted-public-keys = [
                "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
              ];
            };

            nixpkgs.config = {
              nvidia.acceptLicense = true;
              cudaSupport = true;
              cudnnSupport = true;
            };

            environment = {
              systemPackages = with pkgs; [
                lact
                pciutils
                nvtopPackages.full
                libva-utils
                gwe
                vulkan-tools
                mesa-demos
                zenith-nvidia
                nvitop
                btop-cuda
                vulkan-loader
                vulkan-validation-layers
              ];

              variables = {
                CUDA_PATH = "${pkgs.cudatoolkit}";
              };
            };
          };
      };

      driver = den.lib.perHost {
        nixos =
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
                  "NVreg_UsePageAttributeTable=1"
                  "nvidia.NVreg_EnableGpuFirmware=1"
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
              package = config.boot.kernelPackages.nvidiaPackages.latest;
            };
          };
      };

      kernel = den.lib.perHost {
        nixos = {
          boot.kernelModules = [
            "nvidia"
            "nvidia_modeset"
            "nvidia_drm"
            "nvidia_uvm"
          ];
        };
      };
    };
  };
}

{
  den.aspects.hardware.gpu.nvidia = {
    nixos =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
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
              "NVreg_UsePageAttributeTable=1"
              "nvidia.NVreg_EnableGpuFirmware=1"
              "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
            ];
        };

        services.xserver.videoDrivers = [ "nvidia" ];

        hardware.graphics = {
          enable = true;
          extraPackages = [
            pkgs.libva-vdpau-driver
            pkgs.libvdpau
            pkgs.libvdpau-va-gl
            pkgs.nvidia-vaapi-driver
            pkgs.vdpauinfo
            pkgs.libva
            pkgs.libva-utils
          ];
        };

        hardware.nvidia = {
          forceFullCompositionPipeline = false;
          modesetting.enable = true;
          powerManagement.enable = true;
          open = true;
          nvidiaSettings = false;
          nvidiaPersistenced = lib.mkDefault false;
          # nix-cachyos-kernel de-consts __to_hwgpio() with --replace-fail;
          # nvidia-open >=615 already ships it de-consted, so that substitution
          # aborts the build. Downgrade it to a warning.
          package =
            let
              base = config.boot.kernelPackages.nvidiaPackages.latest;
            in
            base.overrideAttrs (_: {
              passthru = base.passthru // {
                open = base.open.overrideAttrs (o: {
                  postPatch = builtins.replaceStrings [ "--replace-fail" ] [ "--replace-warn" ] (o.postPatch or "");
                });
              };
            });
        };

        nixpkgs.config = {
          nvidia.acceptLicense = true;
          # cudaSupport = true; # TODO: Enable CUDA
          # cudnnSupport = true;
        };

        environment = {
          systemPackages = [
            pkgs.lact
            pkgs.pciutils
            pkgs.nvtopPackages.full
            pkgs.libva-utils
            pkgs.gwe
            pkgs.vulkan-tools
            pkgs.mesa-demos
            pkgs.zenith-nvidia
            pkgs.nvitop
            pkgs.btop-cuda
            pkgs.vulkan-loader
            pkgs.vulkan-validation-layers
          ];

          variables = {
            CUDA_PATH = "${pkgs.cudatoolkit}";
          };
        };
      };
  };
}

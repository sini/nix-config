{
  flake.features.gpu-nvidia = {
    requires = [
      "gpu-nvidia-driver"
      "gpu-nvidia-kernel"
    ];

    nixos =
      {
        pkgs,
        ...
      }:
      {

        services.xserver.videoDrivers = [ "nvidia" ];

        nix.settings = {
          substituters = [
            "https://cuda-maintainers.cachix.org"
          ];
          trusted-public-keys = [
            "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
          ];
        };

        # TODO: move to cuda module...
        nixpkgs.config = {
          nvidia.acceptLicense = true;
          cudaSupport = true;
          cudnnSupport = true;
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
            btop-cuda
            vulkanPackages_latest.vulkan-loader
            vulkanPackages_latest.vulkan-validation-layers # From unstable
            vulkanPackages_latest.vulkan-validation-layers
            vulkanPackages_latest.vulkan-tools
            cudaPackages.cudatoolkit
            cudaPackages.cudnn
            cudaPackages.cutensor
            cudaPackages.cuda_cudart
            cudaPackages.cuda_nvrtc
            cudaPackages.cuda_nvcc
            cudaPackages.cuda_nvtx
            cudaPackages.cuda_nvml_dev
          ];

          variables = {
            # TODO: Are these deprecated? Remove?
            # Required to run the correct GBM backend for nvidia GPUs on wayland
            #GBM_BACKEND = "nvidia-drm";
            # Apparently, without this nouveau may attempt to be used instead
            # (despite it being blacklisted)
            #__GLX_VENDOR_LIBRARY_NAME = "nvidia";
            # Hardware cursors are currently broken on wlroots
            WLR_NO_HARDWARE_CURSORS = "1";
            CUDA_PATH = "${pkgs.cudatoolkit}";
          };
        };

        # TODO: Move to OC module...
        # GPU overclocking/undervolting daemon
        systemd.packages = with pkgs; [ lact ];
        systemd.services.lactd.wantedBy = [ "multi-user.target" ];
      };
  };
}

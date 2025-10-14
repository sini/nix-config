{
  flake.features.gpu-nvidia-kernel.nixos = {
    boot.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_drm"
      "nvidia_uvm"
    ];
  };
}

{
  features.gpu-nvidia-kernel.linux = {
    boot.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_drm"
      "nvidia_uvm"
    ];
  };
}

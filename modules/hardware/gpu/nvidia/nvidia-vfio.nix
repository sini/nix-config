{
  flake.features.gpu-nvidia-vfio.nixos =
    {
      config,
      lib,
      ...
    }:
    {
      config =
        let
          nvidiaCard = lib.lists.findFirst (
            card: card.vendor.name == "nVidia Corporation"
          ) null config.facter.report.hardware.graphics_card;

          nvidiaGpuDeviceID =
            if nvidiaCard != null then "${nvidiaCard.vendor.hex}:${nvidiaCard.device.hex}" else "10de:2203";

          nvidiaAudioController = lib.lists.findFirst (
            card: card.vendor.name == "nVidia Corporation"
          ) null config.facter.report.hardware.sound;

          nvidiaAudioDeviceID =
            if nvidiaAudioController != null then
              "${nvidiaAudioController.vendor.hex}:${nvidiaAudioController.device.hex}"
            else
              "10de:1aef";
        in
        {
          services.udev.extraRules = ''
            SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
            SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"
          '';

          # We don't start powerd by default since we've bound the GPU to vfio
          systemd.services.nvidia-powerd.enable = false;

          boot = {
            kernelParams = [
              "vfio-pci.ids=${nvidiaGpuDeviceID},${nvidiaAudioDeviceID}"

              # KVM Settings
              "kvm.ignore_msrs=1" # Ignore unhandled Model Specific Registers
              "kvm.report_ignored_msrs=0" # Don't report ignored MSRs
            ];

            initrd.kernelModules = [
              "vfio_pci"
              "vfio"
              "vfio_iommu_type1"
              "kvmfr"
            ];

            extraModulePackages = with config.boot.kernelPackages; [
              kvmfr
            ];

            blacklistedKernelModules = [
              "nvidia"
              "nvidia_modeset"
              "nvidia_uvm"
              "nvidia_drm"
              "i2c_nvidia_gpu"
              "nvidia-gpu"
              "nouveau"
            ];

            # 256 is for 4k HDR
            extraModprobeConfig = ''
              options vfio-pci ids=${nvidiaGpuDeviceID},${nvidiaAudioDeviceID}"
              options kvmfr static_size_mb=256
              blacklist nouveau
              options nouveau modeset=0
            '';
          };
        };
    };
}

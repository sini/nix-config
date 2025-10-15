{
  flake.features.virtualization.nixos =
    { pkgs, ... }:
    {

      boot.kernelModules = [
        "kvm"
        "vhost-net"
      ];
      boot.kernelParams = [
        # Memory Management
        "default_hugepagesz=2M" # Set default huge page size to 2MB
        "hugepagesz=2M" # Configure huge page size as 2MB
        "transparent_hugepage=never" # Disable transparent huge pages
        "mem_sleep_default=deep" # Set default sleep mode to deep sleep
      ];

      # Install necessary packages
      environment.systemPackages = with pkgs; [
        libguestfs
        spice
        spice-gtk
        spice-protocol
        virt-manager
        virt-viewer
        win-virtio
        win-spice

        virtiofsd
        looking-glass-client # For KVM
        qemu # Virtualizer
        OVMF # UEFI Firmware
        gvfs # Shared Directory
        swtpm # TPM
        virglrenderer # Virtual OpenGL
      ];

      programs.virt-manager.enable = true;

      # TODO: remove hardcoded user 'sini'
      systemd.tmpfiles.rules = [
        "d /dev/hugepages 1770 root kvm -"
        "d /dev/shm 1777 root root -"
        "f /dev/shm/looking-glass 0660 sini kvm -"
      ];

      fileSystems."/dev/hugepages" = {
        device = "hugetlbfs";
        fsType = "hugetlbfs";
        options = [
          "mode=01770"
          "gid=kvm"
        ];
      };

      # Manage the virtualisation services
      virtualisation = {
        kvmgt.enable = true;
        libvirtd = {
          enable = true;
          allowedBridges = [
            "nm-bridge"
            "virbr0"
          ];
          onBoot = "ignore";
          onShutdown = "shutdown";
          qemu = {
            swtpm.enable = true;
            runAsRoot = true;
            verbatimConfig = ''
              user = "sini"
              group = "kvm"
              cgroup_device_acl = [
                "/dev/null", "/dev/full", "/dev/zero",
                "/dev/random", "/dev/urandom",
                "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
                "/dev/rtc","/dev/hpet", "/dev/sev",
                "/dev/kvmfr0",
                "/dev/vfio/vfio"
              ]
              hugetlbfs_mount = "/dev/hugepages"
              bridge_helper = "/run/wrappers/bin/qemu-bridge-helper"
            '';
          };
        };
        spiceUSBRedirection.enable = true;
      };

      services.spice-vdagentd.enable = true;
    };
}

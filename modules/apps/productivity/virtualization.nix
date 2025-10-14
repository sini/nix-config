{
  flake.features.virtualization.nixos =
    { pkgs, ... }:
    {

      boot.kernelModules = [ "vhost-net" ];
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
          };
        };
        spiceUSBRedirection.enable = true;
      };

      services.spice-vdagentd.enable = true;
    };
}

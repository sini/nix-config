{ ... }:
{
  flake.hosts.vm-test = {
    ipv4 = [ "10.10.44.135" ];
    ipv6 = [ "fd64:0:3::2/64" ];
    environment = "prod";
    roles = [
      "server"
      # "kubernetes"
      # "kubernetes-master"
      # "bgp-spoke"
      # "vault"
    ];
    features = [
      # "disk-longhorn"
      # "zfs-disk-single"
      "disk-single"
      # "cpu-amd"
      # "gpu-amd"
      # "thunderbolt-mesh"
    ];
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        services.getty.autologinUser = "sini";
        users.users.root.password = "root";
        boot.kernelPackages = pkgs.linuxPackages_cachyos-server;
        boot.initrd.availableKernelModules = [
          "ahci"
          "xhci_pci"
          "virtio_pci"
          "virtio_scsi"
          "sd_mod"
          "sr_mod"
          "virtio_net"
        ];
        hardware = {
          networking = {
            interfaces = [ "enp1s0" ];
            unmanagedInterfaces = [ "enp1s0" ];
          };
          disk.single.device_id = "/dev/disk/by-id/ata-QEMU_HARDDISK_QM00003";
          # disk.zfs-disk-single.device_id = "/dev/disk/by-id/ata-QEMU_HARDDISK_QM00003";
        };

        impermanence = {
          enable = true;
          wipeRootOnBoot = true;
          wipeHomeOnBoot = true;
        };
        system.stateVersion = "25.05";
      };
  };
}

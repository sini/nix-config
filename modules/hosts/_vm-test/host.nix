{ ... }:
{
  flake.hosts.vm-test = {
    ipv4 = [ "10.10.210.149" ];
    ipv6 = [ "fd64:0:3::2/64" ];
    environment = "dev";
    roles = [
      "server"
      # "kubernetes"
      # "bgp-spoke"
      # "vault"
      "metrics-ingester"
    ];
    features = [
      # "disk-single"
      "zfs-disk-single"
      # "btrfs-impermanence-single"
      # "cpu-amd"
      # "gpu-amd"
      # "thunderbolt-mesh"
      "acme"
      "nginx"
      "kanidm"
      "grafana"
      "loki"
      "prometheus"
      "docker"
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
          networking.interfaces = [ "enp1s0" ];
          # disk.single.device_id = "ata-QEMU_HARDDISK_QM00003";
          # disk.btrfs-impermanence-single.device_id = "/dev/disk/by-id/ata-QEMU_HARDDISK_QM00003";
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/ata-QEMU_HARDDISK_QM00003";
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

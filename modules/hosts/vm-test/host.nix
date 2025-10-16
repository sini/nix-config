{ ... }:
{
  flake.hosts.vm-test = {
    ipv4 = [ "10.10.210.149" ];
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
      "zfs-disk-single"
      "zfs"
      "impermenance"
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
        boot.kernelPackages = pkgs.linuxPackages_cachyos-server;

        hardware = {
          networking = {
            interfaces = [ "enp1s0" ];
            unmanagedInterfaces = [ "enp1s0" ];
          };
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/ata-QEMU_HARDDISK_QM00003";
        };

        system.stateVersion = "25.05";
      };
  };
}

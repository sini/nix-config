{ ... }:
{
  flake.hosts.axon-01 = {
    ipv4 = [ "10.10.10.2" ];
    ipv6 = [ "fd64:0:1::2/64" ];
    environment = "prod";
    roles = [
      "server"
      "unlock"
      "kubernetes"
      "kubernetes-master"
      "bgp-spoke"
      "nix-builder"
      # "vault"
    ];
    features = [
      "zfs-disk-single"
      "cpu-amd"
      "gpu-amd"
      "thunderbolt-mesh"
      "cilium-bgp"
    ];
    tags = {
      "kubernetes-internal-ip" = "172.16.255.1";
      "kubernetes-cilium-bgp-id" = "172.16.255.11";
      "bgp-asn" = "65001";
      # "thunderbolt-loopback-ipv4" = "172.16.255.1/32";
      # "thunderbolt-loopback-ipv6" = "fdb4:5edb:1b00::1/128";
      "thunderbolt-interface-1" = "169.254.12.0/31";
      "thunderbolt-interface-2" = "169.254.31.1/31";
    };
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;

        hardware = {
          networking.interfaces = [ "enp2s0" ];
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_00230650035M";
          # disk.longhorn = {
          #   longhorn_drive = {
          #     device_id = "nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
          #   };
          # };
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

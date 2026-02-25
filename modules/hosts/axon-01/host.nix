{ ... }:
{
  flake.hosts.axon-01 = {
    ipv4 = [ "10.10.10.2" ];
    ipv6 = [ "fd64:0:1::2/64" ];
    environment = "prod";
    roles = [
      "server"
      "unlock"
      # "kubernetes" # TOGGLE_ENABLE/DISABLE
      # "kubernetes-master" # TOGGLE_ENABLE/DISABLE
      "bgp-spoke"
      "nix-builder"
      # "vault"
    ];
    features = [
      "zfs-disk-single"
      "cpu-amd"
      "gpu-amd"
      "thunderbolt-mesh"
    ];
    tags = {
      "bgp-asn" = "65001";
      "cilium-asn" = "65002";

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

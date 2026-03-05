{ ... }:
{
  flake.hosts.axon-03 = {
    ipv4 = [ "10.10.10.4" ];
    ipv6 = [ "fe80::dc50:e5ff:feac:7353" ];
    environment = "prod";
    roles = [
      "server"
      "unlock"
      "kubernetes" # TOGGLE_ENABLE/DISABLE
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
      "bgp-asn" = "65001";
      "cilium-asn" = "65002";
      "ceph-device" = "/dev/disk/by-id/nvme-Force_MP600_1925823000012856500E";

      "thunderbolt-interface-1" = "169.254.31.0/31";
      "thunderbolt-interface-2" = "169.254.23.1/31";
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
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300CCCC";
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

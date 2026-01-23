{ ... }:
{
  flake.hosts.axon-03 = {
    ipv4 = [ "10.10.10.4" ];
    ipv6 = [ "fd64:0:1::4/64" ];
    environment = "prod";
    roles = [
      "server"
      "unlock"
      # "kubernetes"
      "bgp-spoke"
      # "vault"
    ];
    features = [
      "zfs-disk-single"
      "cpu-amd"
      "gpu-amd"
      "thunderbolt-mesh"
    ];
    tags = {
      "kubernetes-internal-ip" = "172.16.255.3";
      "bgp-asn" = "65003";
      "thunderbolt-loopback-ipv4" = "172.16.255.3/32";
      "thunderbolt-loopback-ipv6" = "fdb4:5edb:1b00::3/128";
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
          # disk.longhorn = {
          #   longhorn_drive = {
          #     device_id = "nvme-Force_MP600_1925823000012856500E";
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

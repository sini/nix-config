{
  flake.hosts.axon-03 = {
    environment = "prod";
    networking = {
      interfaces.enp2s0 = {
        ipv4 = [ "10.10.10.4" ];
        ipv6 = [ "fe80::dc50:e5ff:feac:7353" ];
      };
      unmanagedInterfaces = [
        "enp199s0f5"
        "enp199s0f6"
      ];
    };
    roles = [
      "server"
      "unlock"
      "k3s" # TOGGLE_ENABLE/DISABLE
      "bgp-spoke"
      "nix-builder"
      "thunderbolt-mesh"
      # "vault"
    ];
    features = [
      "zfs-disk-single"
      "xfs-disk-longhorn"
      "cpu-amd"
      "gpu-amd"
      "cilium-bgp"
    ];
    tags = {
      "bgp-asn" = "65001";
      "cilium-asn" = "65010";

      "thunderbolt-interface-1" = "169.254.31.0/31";
      "thunderbolt-interface-2" = "169.254.23.1/31";
    };
    facts = ./facter.json;
    nixosConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;

        hardware = {
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300CCCC";
          disk.longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_1925823000012856500E";
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

{
  flake.hosts.axon-01 = {
    environment = "prod";
    networking = {
      interfaces.enp2s0 = {
        ipv4 = [ "10.10.10.2" ];
        ipv6 = [ "fe80::40d7:8aff:fe8e:fee4" ];
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

      "thunderbolt-interface-1" = "169.254.12.0/31";
      "thunderbolt-interface-2" = "169.254.31.1/31";
    };
    facts = ./facter.json;
    systemConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;

        hardware = {
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_00230650035M";
          disk.longhorn.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
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

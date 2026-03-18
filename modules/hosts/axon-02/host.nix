{
  flake.hosts.axon-02 = {
    environment = "prod";
    networking = {
      interfaces.enp2s0 = {
        ipv4 = [ "10.10.10.3" ];
        ipv6 = [ "fe80::24d8:31ff:fe26:e771" ];
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
    extra-features = [
      "zfs-disk-single"
      "xfs-disk-longhorn"
      "cpu-amd"
      "gpu-amd"
      "cilium-bgp"
    ];
    tags = {
      "bgp-asn" = "65001";
      "cilium-asn" = "65010";

      "thunderbolt-interface-1" = "169.254.23.0/31";
      "thunderbolt-interface-2" = "169.254.12.1/31";
    };
    facts = ./facter.json;
    systemConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;

        hardware = {
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
          disk.longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_192482300001285610CF";
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

{ ... }:
{
  flake.hosts.axon-02 = {
    ipv4 = [ "10.10.10.3" ];
    ipv6 = [ "fd64:0:1::3/64" ];
    environment = "prod";
    roles = [
      "server"
      "unlock"
      "kubernetes"
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
      "kubernetes-internal-ip" = "172.16.255.2";
      "kubernetes-cilium-bgp-id" = "172.16.255.12";
      "bgp-asn" = "65002";
      # "thunderbolt-loopback-ipv4" = "172.16.255.2/32";
      # "thunderbolt-loopback-ipv6" = "fdb4:5edb:1b00::2/128";
      "thunderbolt-interface-1" = "169.254.23.0/31";
      "thunderbolt-interface-2" = "169.254.12.1/31";
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
          disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
          # disk.longhorn = {
          #   longhorn_drive = {
          #     device_id = "nvme-Force_MP600_192482300001285610CF";
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

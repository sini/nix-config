{
  hosts.axon-03 = {
    environment = "prod";
    networking.interfaces.enp2s0 = {
      ipv4 = [ "10.10.10.4/16" ];
      ipv6 = [ "fe80::dc50:e5ff:feac:7353" ];
    };
    extra-features = [
      # Composite features (formerly roles)
      "server"
      "unlock"
      "k3s"
      "bgp-spoke"
      "nix-builder"
      "thunderbolt-mesh-of"

      # Hardware and system features
      "zfs-disk-single"
      "xfs-disk-longhorn"
      "cpu-amd"
      "gpu-amd"
      "cilium-bgp"
    ];
    settings = {
      bgp.localAsn = 65003;
      cilium-bgp.localAsn = 65010;
      thunderbolt-mesh-of = {
        interfaces = [
          "tb0"
          "tb1"
        ];
        loopback.ipv4 = "172.16.255.3/32";
        nsap = "49.0000.0000.0003.00";
      };
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300CCCC";
      xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_1925823000012856500E";
      impermanence.wipeHomeOnBoot = true;
    };

    facts = ./facter.json;
  };
}

{
  hosts.axon-02 = {
    environment = "prod";
    networking.interfaces.enp2s0 = {
      ipv4 = [ "10.10.10.3/16" ];
      ipv6 = [ "fe80::24d8:31ff:fe26:e771" ];
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
      bgp.localAsn = 65002;
      cilium-bgp.localAsn = 65010;
      thunderbolt-mesh-of = {
        interfaces = [
          "tb0"
          "tb1"
        ];
        loopback.ipv4 = "172.16.255.2/32";
        nsap = "49.0000.0000.0002.00";
      };
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
      xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_192482300001285610CF";
      impermanence.wipeHomeOnBoot = true;
    };

    facts = ./facter.json;
  };
}

{
  hosts.axon-01 = {
    environment = "prod";
    networking.interfaces.enp2s0 = {
      ipv4 = [ "10.10.10.2/16" ];
      ipv6 = [ "fe80::40d7:8aff:fe8e:fee4" ];
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
      bgp.localAsn = 65001;
      cilium-bgp.localAsn = 65010;
      thunderbolt-mesh-of = {
        interfaces = [
          "tb0"
          "tb1"
        ];
        loopback.ipv4 = "172.16.255.1/32";
        nsap = "49.0000.0000.0001.00";
      };
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_00230650035M";
      xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
      impermanence.wipeHomeOnBoot = true;
    };

    facts = ./facter.json;
  };
}

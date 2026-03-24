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
      # "thunderbolt-mesh" # replaced by thunderbolt-mesh-of (OpenFabric)
      "thunderbolt-mesh-of"

      # Hardware and system features
      "zfs-disk-single"
      "xfs-disk-longhorn"
      "cpu-amd"
      "gpu-amd"
      "cilium-bgp"
    ];
    feature-settings.bgp.localAsn = 65001;
    feature-settings.cilium-bgp.localAsn = 65010;
    feature-settings.thunderbolt-mesh-of = {
      interfaces = [
        "enp199s0f5"
        "enp199s0f6"
      ];
      loopback.ipv4 = "172.16.255.1/32";
      nsap = "49.0000.0000.0001.00";
    };
    feature-settings.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_00230650035M";
    feature-settings.xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
    feature-settings.impermanence.wipeHomeOnBoot = true;

    facts = ./facter.json;
    systemConfiguration = _: {
      # Thunderbolt link renaming: PCI path → stable device names
      systemd.network.links = {
        "20-thunderbolt-port-1" = {
          matchConfig = {
            Path = "pci-0000:c7:00.5";
            Driver = "thunderbolt-net";
          };
          linkConfig = {
            Name = "enp199s0f5";
            Alias = "tb1";
            AlternativeName = "tb1";
          };
        };
        "20-thunderbolt-port-2" = {
          matchConfig = {
            Path = "pci-0000:c7:00.6";
            Driver = "thunderbolt-net";
          };
          linkConfig = {
            Name = "enp199s0f6";
            Alias = "tb2";
            AlternativeName = "tb2";
          };
        };
      };
    };
  };
}

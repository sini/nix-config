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
      # "thunderbolt-mesh" # replaced by thunderbolt-mesh-of (OpenFabric)
      "thunderbolt-mesh-of"

      # Hardware and system features
      "zfs-disk-single"
      "xfs-disk-longhorn"
      "cpu-amd"
      "gpu-amd"
      "cilium-bgp"
    ];
    feature-settings.bgp.localAsn = 65002;
    feature-settings.cilium-bgp.localAsn = 65010;
    feature-settings.thunderbolt-mesh-of = {
      interfaces = [
        "enp199s0f5"
        "enp199s0f6"
      ];
      loopback.ipv4 = "172.16.255.2/32";
      nsap = "49.0000.0000.0002.00";
    };
    feature-settings.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
    feature-settings.xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_192482300001285610CF";
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

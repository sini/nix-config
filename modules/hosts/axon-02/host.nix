{
  hosts.axon-02 = {
    environment = "prod";
    networking.interfaces = {
      enp2s0 = {
        ipv4 = [ "10.10.10.3/16" ];
        ipv6 = [ "fe80::24d8:31ff:fe26:e771" ];
      };
      enp199s0f5 = {
        ipv4 = [ "169.254.23.0/31" ];
        managed = false;
        mtu = 1500;
      };
      enp199s0f6 = {
        ipv4 = [ "169.254.12.1/31" ];
        managed = false;
        mtu = 1500;
      };
    };
    extra-features = [
      # Composite features (formerly roles)
      "server"
      "unlock"
      "k3s"
      "bgp-spoke"
      "nix-builder"
      "thunderbolt-mesh"

      # Hardware and system features
      "zfs-disk-single"
      "xfs-disk-longhorn"
      "cpu-amd"
      "gpu-amd"
      "cilium-bgp"
    ];
    feature-settings.bgp.localAsn = 65002;
    feature-settings.cilium-bgp.localAsn = 65010;
    feature-settings.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
    feature-settings.xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_192482300001285610CF";
    feature-settings.impermanence.wipeHomeOnBoot = true;

    facts = ./facter.json;
  };
}

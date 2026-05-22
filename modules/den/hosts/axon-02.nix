{ den, ... }:
{
  den.hosts.x86_64-linux.axon-02 = {
    channel = "nixos-unstable";
    environment = "prod";

    networking.interfaces = {
      enp2s0 = {
        ipv4 = [ "10.10.10.3/16" ];
        ipv6 = [ "fe80::24d8:31ff:fe26:e771" ];
      };
      enp199s0f5 = { };
      enp199s0f6 = { };
    };

    settings = {
      services.bgp.localAsn = 65001;
      services.cilium-bgp.localAsn = 65010;
      services.k3s.clusterName = "axon";
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
      disk.xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_192482300001285610CF";
      disk.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
    };
  };

  den.aspects.hosts.axon-02 = {
    includes = with den.aspects; [
      core.default
      secrets.agenix
      networking
      network.openssh
      network.network-boot
      disk.zfs-disk-single
      disk.xfs-disk-longhorn
      disk.impermanence
      roles.server
      services.bgp.spoke
      services.cilium-bgp
      services.k3s
      hardware.cpu-amd
      hardware.gpu-amd
    ];
  };
}

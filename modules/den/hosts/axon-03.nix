{ den, ... }:
{
  den.hosts.x86_64-linux.axon-03 = {
    channel = "nixos-unstable";
    environment = "prod";
    system-owner = "sini";
    system-access-groups = [ "server-access" ];

    networking.interfaces = {
      enp2s0 = {
        ipv4 = [ "10.10.10.4/16" ];
        ipv6 = [ "fe80::dc50:e5ff:feac:7353" ];
      };
      enp199s0f5 = { };
      enp199s0f6 = { };
    };

    settings = {
      services.bgp.localAsn = 65001;
      services.cilium-bgp.localAsn = 65010;
      services.k3s.clusterName = "axon";
      services.thunderbolt-mesh-of = {
        interfaces = [
          "enp199s0f5"
          "enp199s0f6"
        ];
        loopback.ipv4 = "172.16.255.3/32";
        nsap = "49.0000.0000.0003.00";
      };
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300CCCC";
      disk.xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_1925823000012856500E";
      disk.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
    };
  };

  den.aspects.axon-03 = {
    includes = with den.aspects; [
      core.default
      secrets.agenix
      network.networking
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
      services.thunderbolt-mesh-of
    ];
  };
}

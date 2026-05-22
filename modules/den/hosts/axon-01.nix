{ den, ... }:
{
  den.hosts.x86_64-linux.axon-01 = {
    channel = "nixos-unstable";
    environment = "prod";
    system-owner = "sini";
    system-access-groups = [ "server-access" ];

    networking.interfaces = {
      enp2s0 = {
        ipv4 = [ "10.10.10.2/16" ];
        ipv6 = [ "fe80::40d7:8aff:fe8e:fee4" ];
      };
      enp199s0f5 = { };
      enp199s0f6 = { };
    };

    settings = {
      services.bgp.localAsn = 65001;
      services.cilium-bgp.localAsn = 65010;
      services.k3s.clusterName = "axon";
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_00230650035M";
      disk.xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
      disk.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
    };
  };

  den.aspects.axon-01 = {
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

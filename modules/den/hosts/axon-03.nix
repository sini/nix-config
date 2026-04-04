{ den, rootPath, ... }:
{
  den.hosts.x86_64-linux.axon-03 = {
    environment = "prod";
    system-access-groups = [ "server-access" ];
    networking.interfaces.enp2s0 = {
      ipv4 = [ "10.10.10.4/16" ];
      ipv6 = [ "fe80::dc50:e5ff:feac:7353" ];
    };
    facts = ../../hosts/axon-03/facter.json;
    public_key = rootPath + "/.secrets/hosts/axon-03/ssh_host_ed25519_key.pub";

    settings = {
      bgp.localAsn = 65001;
      cilium-bgp.localAsn = 65010;
      thunderbolt-mesh-of = {
        interfaces = [
          "enp199s0f5"
          "enp199s0f6"
        ];
        loopback.ipv4 = "172.16.255.3/32";
        nsap = "49.0000.0000.0003.00";
      };
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300CCCC";
      xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_1925823000012856500E";
      impermanence.wipeHomeOnBoot = true;
    };
  };

  den.aspects.axon-03 = {
    includes = [
      den.aspects.default
      den.aspects.zfs-disk-single
      den.aspects.impermanence-zfs
      den.aspects.zfs-diff
      den.aspects.xfs-disk-longhorn
      den.aspects.server
      den.aspects.unlock
      den.aspects.nix-builder
      den.aspects.k3s
      den.aspects.bgp-spoke
      den.aspects.cilium-bgp
      den.aspects.thunderbolt-mesh-of
      den.aspects.cpu-amd
      den.aspects.gpu-amd
    ];
  };
}

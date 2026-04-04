{
  den,
  inputs,
  rootPath,
  ...
}:
{
  den.hosts.x86_64-linux.axon-01 = {
    instantiate = inputs.nixpkgs-unstable.lib.nixosSystem;
    environment = "prod";
    system-access-groups = [ "server-access" ];
    networking.interfaces.enp2s0 = {
      ipv4 = [ "10.10.10.2/16" ];
      ipv6 = [ "fe80::40d7:8aff:fe8e:fee4" ];
    };
    facts = ../../hosts/axon-01/facter.json;
    public_key = rootPath + "/.secrets/hosts/axon-01/ssh_host_ed25519_key.pub";

    settings = {
      bgp.localAsn = 65001;
      cilium-bgp.localAsn = 65010;
      thunderbolt-mesh-of = {
        interfaces = [
          "enp199s0f5"
          "enp199s0f6"
        ];
        loopback.ipv4 = "172.16.255.1/32";
        nsap = "49.0000.0000.0001.00";
      };
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_00230650035M";
      xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310395L";
      impermanence.wipeHomeOnBoot = true;
    };
  };

  den.aspects.axon-01 = {
    includes = [
      den.aspects.default
      # Disk
      den.aspects.zfs-disk-single
      den.aspects.impermanence-zfs
      den.aspects.zfs-diff
      den.aspects.xfs-disk-longhorn
      # Roles
      den.aspects.server
      den.aspects.unlock
      den.aspects.nix-builder
      # Kubernetes
      den.aspects.k3s
      den.aspects.bgp-spoke
      den.aspects.cilium-bgp
      den.aspects.thunderbolt-mesh-of
      # Hardware
      den.aspects.cpu-amd
      den.aspects.gpu-amd
    ];
  };
}

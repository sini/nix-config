{
  den,
  inputs,
  rootPath,
  ...
}:
{
  den.hosts.x86_64-linux.axon-02 = {
    instantiate = inputs.nixpkgs-unstable.lib.nixosSystem;
    environment = "prod";
    system-access-groups = [ "server-access" ];
    networking.interfaces.enp2s0 = {
      ipv4 = [ "10.10.10.3/16" ];
      ipv6 = [ "fe80::24d8:31ff:fe26:e771" ];
    };
    facts = ../../hosts/axon-02/facter.json;
    public_key = rootPath + "/.secrets/hosts/axon-02/ssh_host_ed25519_key.pub";

    settings = {
      bgp.localAsn = 65001;
      cilium-bgp.localAsn = 65010;
      thunderbolt-mesh-of = {
        interfaces = [
          "enp199s0f5"
          "enp199s0f6"
        ];
        loopback.ipv4 = "172.16.255.2/32";
        nsap = "49.0000.0000.0002.00";
      };
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
      xfs-disk-longhorn.device_id = "/dev/disk/by-id/nvme-Force_MP600_192482300001285610CF";
      impermanence.wipeHomeOnBoot = true;
    };
  };

  den.aspects.axon-02 = {
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

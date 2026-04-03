{
  den,
  rootPath,
  ...
}:
{
  den.hosts.x86_64-linux.bitstream = {
    environment = "dev";
    system-access-groups = [ "server-access" ];
    networking = {
      bonds.bond0 = {
        interfaces = [
          "eno1"
          "enp2s0"
        ];
        mode = "balance-xor";
        transmitHashPolicy = "layer3+4";
      };
      interfaces.bond0 = {
        ipv4 = [ "10.9.1.1/16" ];
        ipv6 = [ "2001:5a8:608c:4a00::1/64" ];
      };
    };
    facts = ../../hosts/bitstream/facter.json;
    public_key = rootPath + "/.secrets/hosts/bitstream/ssh_host_ed25519_key.pub";

    settings = {
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_0023065001TG";
      impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = false;
      };
      linux-kernel.optimization = "server";
    };
  };

  den.aspects.bitstream = {
    includes = [
      den.aspects.default
      # Disk
      den.aspects.zfs-disk-single
      den.aspects.impermanence-zfs
      den.aspects.zfs-diff
      # Roles
      den.aspects.server
      den.aspects.nix-builder
      # Hardware
      den.aspects.cpu-amd
      den.aspects.gpu-amd
    ];
  };
}

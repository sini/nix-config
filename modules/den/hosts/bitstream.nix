{ den, ... }:
{
  den.hosts.x86_64-linux.bitstream = {
    channel = "nixos-unstable";
    environment = "dev";

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

    settings = {
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_0023065001TG";
      impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = false;
      };
    };
  };

  den.aspects.bitstream = {
    includes = with den.aspects; [
      core.default
      secrets.agenix
      network.networking
      network.openssh
      disk.zfs
      disk.impermanence
      roles.server
      roles.nix-builder
      hardware.cpu-amd
      hardware.gpu-amd
    ];
  };
}

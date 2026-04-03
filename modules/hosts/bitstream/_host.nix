{
  hosts.bitstream = {
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
    environment = "dev";
    extra-features = [
      # Composite features (formerly roles)
      "server"
      "nix-builder"

      # Hardware and system features
      "zfs-disk-single"
      "network-boot"
      "cpu-amd"
      "gpu-amd"
    ];
    settings.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_0023065001TG";

    facts = ./facter.json;
  };
}

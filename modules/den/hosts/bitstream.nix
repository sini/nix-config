{ den, inputs, ... }:
{
  den.hosts.x86_64-linux.bitstream = {
    # Metadata needed for user resolution and networking
    environment = "dev";
    system-access-groups = [ "server-access" ];
    zfs-device = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_0023065001TG";
    impermanence = {
      wipeRootOnBoot = true;
      wipeHomeOnBoot = false;
    };
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
    public_key = ../../.secrets/hosts/bitstream/ssh_host_ed25519_key.pub;
  };

  den.aspects.bitstream = {
    includes = [
      den.aspects.default
      den.aspects.zfs-disk-single
      den.aspects.impermanence-zfs
      den.aspects.zfs-diff
    ];

    nixos =
      { ... }:
      {
        imports = [
          inputs.nixos-facter-modules.nixosModules.facter
        ];

        facter.reportPath = ../../hosts/bitstream/facter.json;

        nixpkgs.hostPlatform = "x86_64-linux";

        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
      };
  };
}

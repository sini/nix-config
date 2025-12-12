{ ... }:
{
  flake.hosts.brick = {
    ipv4 = [ "10.9.4.1" ];
    ipv6 = [ "2001:5a8:608c:4a00::41/64" ];
    environment = "dev";
    roles = [
      "workstation"
      "laptop"
      "gaming"
      "dev"
      "dev-gui"
      "media"
    ];
    features = [
      "cpu-intel"
      "gpu-intel"
      "zfs-disk-single"
      "network-manager"
    ];
    users = {
      "sini" = {
        "features" = [
          "spotify-player"
        ];
      };
    };
    facts = ./facter.json;
    nixosConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.linuxPackages_cachyos;

        hardware.disk.zfs-disk-single.device_id = "/dev/disk/by-id/ata-TOSHIBA_THNSNJ512GCSU_55PS103TT8PW";

        impermanence = {
          enable = true;
          wipeRootOnBoot = true;
          wipeHomeOnBoot = true;
        };

        system.stateVersion = "25.05";
      };
  };
}

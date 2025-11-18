{ ... }:
{
  flake.hosts.blade = {
    ipv4 = [ "10.9.3.1" ];
    ipv6 = [ "2001:5a8:608c:4a00::31/64" ];
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
      "gpu-nvidia"
      "gpu-nvidia-prime"
      "zfs-disk-single"
      "network-manager"
      "razer"
      "gamedev"
    ];
    users = {
      "shuo" = {
        "features" = [
          "firefox"
          "steam"
          "spicetify"
        ];
      };
    };
    facts = ./facter.json;
    nixosConfiguration =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.linuxPackages_cachyos.cachyOverride { mArch = "GENERIC_V4"; };

        hardware.disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-CT4000P3PSSD8_2431E8BD13D9";

        impermanence = {
          enable = true;
          wipeRootOnBoot = true;
          wipeHomeOnBoot = true;
        };

        system.stateVersion = "25.05";
      };
  };
}

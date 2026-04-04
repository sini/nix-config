{
  den,

  rootPath,
  ...
}:
{
  den.hosts.x86_64-linux.blade = {
    channel = "nixpkgs-master";
    environment = "dev";
    system-owner = "sini";
    system-access-groups = [ "workstation-access" ];
    networking.interfaces.wlp0s20f3.dhcp = "yes";
    users = {
      sini.classes = [ "homeManager" ];
      shuo.classes = [ "homeManager" ];
      will.classes = [ "homeManager" ];
    };
    facts = ../../hosts/blade/facter.json;
    public_key = rootPath + "/.secrets/hosts/blade/ssh_host_ed25519_key.pub";

    settings = {
      zfs-disk-single.device_id = "/dev/disk/by-id/nvme-CT4000P3PSSD8_2431E8BD13D9";
      linux-kernel.optimization = "x86_64-v4";
    };
  };

  den.aspects.blade = {
    includes = [
      den.aspects.default
      # Disk
      den.aspects.zfs-disk-single
      den.aspects.impermanence-zfs
      den.aspects.zfs-diff
      # Roles
      den.aspects.workstation
      den.aspects.gaming
      den.aspects.dev
      den.aspects.dev-gui
      den.aspects.media
      # Hardware
      den.aspects.laptop
      den.aspects.cpu-intel
      den.aspects.gpu-intel
      den.aspects.gpu-nvidia
      den.aspects.gpu-nvidia-prime
      den.aspects.performance
      den.aspects.razer
      # Network
      den.aspects.network-manager
      den.aspects.tailscale
      den.aspects.network-boot
      den.aspects.wireless-initrd
      # Apps
      den.aspects.discord
    ];

    # Per-user aspects via mutual-provider
    provides.sini = {
      includes = [
        den.aspects.spotify-player
        den.aspects.waybar
        den.aspects.swaync
        den.aspects.hypridle
        den.aspects.hyprland-split-monitors
      ];
    };

    provides.shuo = {
      includes = [
        den.aspects.firefox
        den.aspects.steam
        den.aspects.spicetify
      ];
    };
  };
}

{
  den,
  rootPath,
  ...
}:
{
  den.hosts.x86_64-linux.blade = {
    environment = "dev";
    # TODO: channel = "nixpkgs-master" — channels not in den yet
    system-access-groups = [ "workstation-access" ];
    networking.interfaces.wlp0s20f3.dhcp = "yes";
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

    # TODO: Per-user feature overrides not in den yet
    # users.sini.extra-features = [ "spotify-player" "waybar" "swaync" "hypridle" "hyprland-split-monitors" ]
    # users.shuo.extra-features = [ "firefox" "steam" "spicetify" ]
  };
}

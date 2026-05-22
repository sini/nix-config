{ den, ... }:
{
  den.hosts.x86_64-linux.blade = {
    channel = "nixpkgs-master";
    environment = "dev";
    system-owner = "sini";
    system-access-groups = [ "workstation-access" ];

    networking.interfaces.wlp0s20f3 = {
      dhcp = "yes";
    };

    settings = {
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-CT4000P3PSSD8_2431E8BD13D9";
      core.linux-kernel.optimization = "x86_64-v4";
      disk.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
    };
  };

  den.aspects.blade = {
    includes = with den.aspects; [
      roles.workstation
      roles.laptop
      roles.gaming
      roles.dev
      roles.dev-gui
      roles.media
      hardware.cpu-intel
      hardware.gpu-intel
      hardware.gpu-nvidia
      hardware.gpu-nvidia-prime
      hardware.razer
      hardware.performance
      desktop.hyprland
      desktop.uwsm
      disk.zfs-disk-single
      disk.impermanence
      network.network-boot
      network.openssh
      network.network-manager
      services.tailscale
      apps.discord
      secrets.agenix
      core.default
    ];

    sini = {
      includes = with den.aspects; [
        apps.waybar
        apps.swaync
        apps.hypridle
        apps.hyprland-split-monitors
        apps.spotify-player
      ];
    };

    shuo = {
      includes = with den.aspects; [
        apps.firefox
        apps.steam
        apps.spicetify
      ];
    };
  };
}

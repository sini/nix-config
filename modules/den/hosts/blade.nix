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
      core.system.linux-kernel.optimization = "x86_64-v4";
      core.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
    };
  };

  den.aspects.blade = {
    includes = with den.aspects; [
      roles.default
      roles.workstation
      roles.laptop
      roles.gaming
      roles.dev
      roles.dev-gui
      roles.media

      hardware.cpu.intel
      hardware.gpu.intel
      hardware.gpu.nvidia
      hardware.gpu.nvidia-prime
      hardware.razer
      hardware.performance

      desktop.hyprland
      desktop.uwsm

      disk.zfs-disk-single

      core.boot.wireless-initrd
      core.network.manager
      services.networking.tailscale
      apps.messaging.discord
    ];

    sini = {
      includes = with den.aspects; [
        apps.wayland.waybar
        apps.wayland.swaync
        apps.wayland.hypridle
        apps.wayland.hyprland-split-monitors
        apps.media.spotify-player
      ];
    };

    shuo = {
      includes = with den.aspects; [
        apps.browsers.firefox
        apps.gaming.steam
        apps.media.spicetify
      ];
    };
  };
}

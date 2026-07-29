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
        wipeHomeOnBoot = false;
      };

      # vic may attach sini's live herdr `pair` session (his key lands on sini's
      # account behind a forced herdr-attach command). See applications.dev.mux.herdr-pair.
      applications.dev.mux.herdr-pair.pairs.sini = [ "vic" ];
    };
  };

  den.aspects.blade = {
    includes = with den.aspects; [
      roles.default
      roles.workstation
      roles.gaming
      roles.dev
      roles.dev-gui
      roles.messaging
      roles.media

      hardware.cpu.intel
      hardware.gpu.intel
      hardware.gpu.nvidia
      hardware.gpu.nvidia-prime
      hardware.laptop
      hardware.razer
      hardware.performance

      # desktop.hyprland
      desktop.uwsm

      disk.zfs-disk-single

      core.boot.wireless-initrd
      core.network.manager
      core.network.tailscale

      applications.dev.mux.herdr-pair
    ];

    sini = {
      includes = with den.aspects; [
        # applications.wayland.waybar
        # applications.wayland.swaync
        # applications.wayland.hypridle
        # applications.wayland.hyprland-split-monitors
        applications.media.spotify-player
      ];
    };

    shuo = {
      includes = with den.aspects; [
        applications.browsers.firefox
        applications.gaming.steam
        applications.media.spicetify
      ];
    };
  };
}

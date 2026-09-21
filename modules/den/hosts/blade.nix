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

    nixos =
      { lib, ... }:
      {
        # thermald stacks a software RAPL clamp on top of the hardware's own
        # TJmax throttling and drives PL1 to ~0W, so the package oscillates
        # between a stall and full power instead of throttling smoothly.
        # Measured under identical all-core load: PL1 spread 100W with it
        # running (20W..120W), 0W with it stopped. The oscillation is what
        # produces the frametime and audio-deadline misses under game load.
        services.thermald.enable = lib.mkForce false;

        # Thermally limited rather than power limited, so shedding voltage at
        # constant frequency is the only tuning that raises sustained clocks
        # instead of just relocating heat. Measured at -75mV core+cache under
        # identical all-core load: +233MHz (+10%) at the same package
        # temperature. coreOffset drives both --core and --cache; the CPU
        # applies the smaller of the two regardless. useTimer because a lost
        # offset is silent -- the machine just runs slower.
        services.undervolt = {
          enable = true;
          coreOffset = -75;
          useTimer = true;
        };
      };

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

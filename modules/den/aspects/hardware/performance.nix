{ den, ... }:
{
  # Note: original feature checks host.hasFeature "laptop" for scx config;
  # in den, laptop hosts would include the laptop aspect which sets scx separately.
  # The scx config here uses mkIf to avoid conflict when laptop aspect is also active.
  den.aspects.performance = den.lib.perHost {
    nixos =
      {
        pkgs,
        lib,
        ...
      }:
      {
        # GPU overclocking/undervolting daemon
        systemd.packages = with pkgs; [ lact ];
        systemd.services.lactd.wantedBy = [ "multi-user.target" ];

        powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

        services = {
          irqbalance.enable = true;
          scx = {
            enable = lib.mkDefault true;
            package = lib.mkDefault pkgs.scx.full;
            scheduler = lib.mkDefault "scx_bpfland";
            extraArgs = lib.mkDefault [
              "-m"
              "performance"
              "-f"
              "-k"
              "-p"
            ];
          };
        };

        services.udev.extraRules = ''
          ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
          ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="1024"
        '';

        # Based on: https://github.com/CachyOS/CachyOS-Settings/blob/e96d1e1dd253ed09e4104b096df543e6ecad08be/usr/lib/sysctl.d/99-cachyos-settings.conf
        boot.kernel.sysctl = {
          "fs.inotify.max_user_watches" = 1048576;
          "fs.inotify.max_user_instances" = 1024;
          "fs.inotify.max_queued_events" = 32768;

          "vm.swappiness" = 100;
          "vm.vfs_cache_pressure" = 50;
          "vm.dirty_bytes" = 268435456;
          "vm.page-cluster" = 0;
          "vm.dirty_background_bytes" = 67108864;
          "vm.dirty_writeback_centisecs" = 1500;
          "vm.max_map_count" = 2147483642;

          "kernel.nmi_watchdog" = 0;
          "kernel.unprivileged_userns_clone" = 1;
          "kernel.printk" = "3 3 3 3";
          "kernel.kptr_restrict" = 2;
          "kernel.kexec_load_disabled" = 1;

          "net.ipv4.tcp_ecn" = 1;
          "net.ipv4.tcp_congestion_control" = "bbr";
          "net.ipv4.tcp_fin_timeout" = 5;
          "net.core.netdev_max_backlog" = 4096;
          "net.ipv4.tcp_slow_start_after_idle" = 0;
          "net.ipv4.tcp_rfc1337" = 1;

          "fs.file-max" = 2097152;
          "fs.xfs.xfssyncd_centisecs" = 10000;

          "kernel.split_lock_mitigate" = 0;
        };
      };
  };
}

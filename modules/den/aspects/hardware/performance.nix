{ den, ... }:
{
  den.aspects.hardware.performance = {
    nixos =
      { pkgs, lib, ... }:
      {
        powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

        services = {
          irqbalance.enable = true;
          scx = {
            enable = true;
            package = lib.mkDefault pkgs.scx.full;
            scheduler = "scx_bpfland";
            extraArgs = [
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

        boot.kernel.sysctl = {
          # Inotify limits
          "fs.inotify.max_user_watches" = 1048576;
          "fs.inotify.max_user_instances" = 1024;
          "fs.inotify.max_queued_events" = 32768;

          # VM tuning
          "vm.swappiness" = 100;
          "vm.vfs_cache_pressure" = 50;
          "vm.dirty_bytes" = 268435456;
          "vm.page-cluster" = 0;
          "vm.dirty_background_bytes" = 67108864;
          "vm.dirty_writeback_centisecs" = 1500;
          "vm.max_map_count" = 2147483642;

          # Kernel
          "kernel.nmi_watchdog" = 0;
          "kernel.unprivileged_userns_clone" = 1;
          "kernel.printk" = "3 3 3 3";
          "kernel.kptr_restrict" = 2;
          "kernel.kexec_load_disabled" = 1;
          "kernel.split_lock_mitigate" = 0;

          # Network
          "net.ipv4.tcp_ecn" = 1;
          "net.ipv4.tcp_congestion_control" = "bbr";
          "net.ipv4.tcp_fin_timeout" = 5;
          "net.core.netdev_max_backlog" = 4096;
          "net.ipv4.tcp_slow_start_after_idle" = 0;
          "net.ipv4.tcp_rfc1337" = 1;

          # Filesystem
          "fs.file-max" = 2097152;
          "fs.xfs.xfssyncd_centisecs" = 10000;
        };
      };
  };
}

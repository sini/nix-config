{
  # ZFS Impermanence Support
  # ========================
  # ZFS-based impermanence rollback (preferred over BTRFS).
  # Benefits: Superior snapshots, shutdown hooks, simpler management, better backups.
  #
  # Automatically enabled when 'zfs-root' feature is active.

  flake.features.impermanence-zfs = {
    linux =
      {
        lib,
        config,
        pkgs,
        activeFeatures,
        ...
      }:
      {
        config = lib.mkIf (lib.elem "zfs-root" activeFeatures) {
          # Boot Rollback Services
          # ======================
          # Early boot (initrd) services that rollback root/home to @empty snapshots.
          # ZFS advantages: Direct rollback with '-r', no manual nested dataset handling, atomic.

          boot.initrd.systemd.services = {
            rollback-zfs-root = lib.mkIf config.impermanence.wipeRootOnBoot {
              description = "Rollback ZFS root dataset to a pristine state";
              wantedBy = [ "initrd.target" ];
              after = [ "zfs-import-zroot.service" ]; # Wait for ZFS pool import
              before = [ "sysroot.mount" ]; # Must complete before root is mounted
              path = [ config.boot.zfs.package ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = ''
                zfs rollback -r zroot/local/root@empty && echo "rollback complete"
              '';
            };

            rollback-zfs-home = lib.mkIf config.impermanence.wipeHomeOnBoot {
              description = "Rollback ZFS home dataset to a pristine state";
              wantedBy = [ "initrd.target" ];
              after = [ "zfs-import-zroot.service" ];
              before = [ "-.mount" ];
              path = [ config.boot.zfs.package ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = ''
                zfs rollback -r zroot/local/home@empty && echo "rollback complete"
              '';
            };
          };

          # Shutdown Hook
          # =============
          # Creates @lastboot snapshots (for recovery) and optionally rolls back to @empty.
          # Recovery: zfs rollback zroot/local/{root,home}@lastboot
          systemd = {
            shutdownRamfs.contents."/etc/systemd/system-shutdown/zpool".source = lib.mkForce (
              pkgs.writeShellScript "zpool-sync-shutdown" ''
                # Create fresh @lastboot snapshots
                ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/root@lastboot" 2>/dev/null || true
                ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/home@lastboot" 2>/dev/null || true
                ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/root@lastboot"
                ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/home@lastboot"

                # Rollback to @empty if wipe enabled (optimization)
                ${lib.optionalString config.impermanence.wipeRootOnBoot ''
                  ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/root@empty"
                ''}
                ${lib.optionalString config.impermanence.wipeHomeOnBoot ''
                  ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/home@empty"
                ''}

                # Sync pool to disk
                exec ${config.boot.zfs.package}/bin/zpool sync
              ''
            );

            shutdownRamfs.storePaths = [ "${config.boot.zfs.package}/bin/zfs" ];
          };
        };
      };
  };
}

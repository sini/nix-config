# ZFS impermanence rollback.
# Initrd services that roll root/home back to @empty, plus a shutdown hook
# that snapshots @lastboot and optionally rolls back.
{ den, lib, ... }:
{
  den.aspects.core.impermanence.zfs = {
    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        wipeRoot = host.settings.core.impermanence.wipeRootOnBoot or false;
        wipeHome = host.settings.core.impermanence.wipeHomeOnBoot or false;
      in
      {
        config = lib.mkIf (host.hasAspect den.aspects.disk.zfs-disk-single) {
          # ZFS rollback services in initrd
          boot.initrd.systemd.services = {
            rollback-zfs-root = lib.mkIf wipeRoot {
              description = "Rollback ZFS root dataset to a pristine state";
              wantedBy = [ "initrd.target" ];
              after = [ "zfs-import-zroot.service" ];
              before = [ "sysroot.mount" ];
              path = [ config.boot.zfs.package ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = ''
                zfs rollback -r zroot/local/root@empty && echo "rollback complete"
              '';
            };

            rollback-zfs-home = lib.mkIf wipeHome {
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

          # Shutdown hook: @lastboot snapshots and optional rollback
          systemd = {
            shutdownRamfs.contents."/etc/systemd/system-shutdown/zpool".source = lib.mkForce (
              pkgs.writeShellScript "zpool-sync-shutdown" ''
                ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/root@lastboot" 2>/dev/null || true
                ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/home@lastboot" 2>/dev/null || true
                ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/root@lastboot"
                ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/home@lastboot"

                ${lib.optionalString wipeRoot ''
                  ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/root@empty"
                ''}
                ${lib.optionalString wipeHome ''
                  ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/home@empty"
                ''}

                exec ${config.boot.zfs.package}/bin/zpool sync
              ''
            );

            shutdownRamfs.storePaths = [ "${config.boot.zfs.package}/bin/zfs" ];
          };
        };
      };
  };
}

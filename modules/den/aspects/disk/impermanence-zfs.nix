# ZFS impermanence rollback services — initrd rollback and shutdown hooks
{ den, ... }:
{
  den.aspects.impermanence-zfs = den.lib.perHost (
    { host }:
    let
      impCfg = host.impermanence or { };
      wipeRootOnBoot = impCfg.wipeRootOnBoot or true;
      wipeHomeOnBoot = impCfg.wipeHomeOnBoot or false;
    in
    {
      nixos =
        {
          lib,
          config,
          pkgs,
          ...
        }:
        {
          boot.initrd.systemd.services = {
            rollback-zfs-root = lib.mkIf wipeRootOnBoot {
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

            rollback-zfs-home = lib.mkIf wipeHomeOnBoot {
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

          systemd = {
            shutdownRamfs.contents."/etc/systemd/system-shutdown/zpool".source = lib.mkForce (
              pkgs.writeShellScript "zpool-sync-shutdown" ''
                # Create fresh @lastboot snapshots
                ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/root@lastboot" 2>/dev/null || true
                ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/home@lastboot" 2>/dev/null || true
                ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/root@lastboot"
                ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/home@lastboot"

                # Rollback to @empty if wipe enabled (optimization)
                ${lib.optionalString wipeRootOnBoot ''
                  ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/root@empty"
                ''}
                ${lib.optionalString wipeHomeOnBoot ''
                  ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/home@empty"
                ''}

                # Sync pool to disk
                exec ${config.boot.zfs.package}/bin/zpool sync
              ''
            );

            shutdownRamfs.storePaths = [ "${config.boot.zfs.package}/bin/zfs" ];
          };
        };
    }
  );
}

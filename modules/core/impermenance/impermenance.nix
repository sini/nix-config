{ inputs, ... }:
{
  flake.features.impermenance.nixos =
    {
      lib,
      config,
      pkgs,
      activeFeatures,
      ...
    }:
    let
      zfsEnabled = lib.elem "zfs" activeFeatures;
    in
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      environment.persistence = {
        "/persist" = {
          hideMounts = true;
          directories = [
            "/var/lib/systemd"
            "/var/lib/nixos"
            "/var/log"
          ];
          files = [
            "/etc/machine-id"
            "/etc/adjtime"
          ];
        };
      };

      # Add ZFS persistent datasets if ZFS is enabled
      disko.devices = lib.mkIf zfsEnabled {
        zpool.zroot.datasets = {
          "local/persist" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/persist";
            options."com.sun:auto-snapshot" = "true";
            postCreateHook = "zfs snapshot zroot/local/persist@empty";
          };
          "local/cache" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/cache";
            options."com.sun:auto-snapshot" = "true";
            postCreateHook = "zfs snapshot zroot/local/cache@empty";
          };
        };
      };

      fileSystems."/persist".neededForBoot = true;
      fileSystems."/cache".neededForBoot = true;

      # This
      boot.initrd.systemd.services = {
        rollback = {
          description = "Rollback ZFS datasets to a pristine state";
          wantedBy = [ "initrd.target" ];
          after = [ "zfs-import-zroot.service" ];
          before = [ "sysroot.mount" ];
          path = with pkgs; [ zfs_cachyos ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            zfs rollback -r zroot/local/root@empty && echo "rollback complete"
          '';
        };
        # Rollback '/home'
        # rollback-home = {
        #   description = "Rollback home directory to a pristine state";
        #   wantedBy = [ "initrd.target" ];
        #   after = [ "zfs-import-zroot.service" ];
        #   before = [ "sysroot.mount" ];
        #   path = with pkgs; [ zfs_cachyos ];
        #   unitConfig.DefaultDependencies = "no";
        #   serviceConfig.Type = "oneshot";
        #   script = ''
        #     zfs rollback -r zroot/local/home@empty && echo "rollback complete"
        #   '';
        # };
      };

      # Take snapshots before shutdown for recovery, then rollback to empty
      systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/zpool".source = lib.mkForce (
        pkgs.writeShellScript "zpool-sync-shutdown" ''
          # Remove existing lastboot snapshots if they exist
          ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/root@lastboot" 2>/dev/null || true
          # ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/home@lastboot" 2>/dev/null || true

          # Take new lastboot snapshots for recovery
          ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/root@lastboot"
          # ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/home@lastboot"

          # Rollback to empty state
          ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/root@empty"
          # ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/home@empty"

          # Sync the pool before shutdown
          exec ${config.boot.zfs.package}/bin/zpool sync
        ''
      );

      systemd.shutdownRamfs.storePaths = [ "${config.boot.zfs.package}/bin/zfs" ];

      systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

      # Needed for home-manager's impermanence allowOther option to work
      programs.fuse.userAllowOther = true;

      systemd.tmpfiles.settings."persistent-dirs" =
        let
          mkHomePersist =
            user:
            lib.optionalAttrs user.createHome {
              "/persist/${user.home}" = {
                d = {
                  group = user.group;
                  user = user.name;
                  mode = user.homeMode;
                };
              };
              "/cache/${user.home}" = {
                d = {
                  group = user.group;
                  user = user.name;
                  mode = user.homeMode;
                };
              };
            };
          users = lib.attrValues config.users.users;
        in
        lib.mkMerge (map mkHomePersist users);
    };
}

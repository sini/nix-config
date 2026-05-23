{
  den,
  lib,
  inputs,
  ...
}:
{
  den.aspects.disk.impermanence = {
    includes = [
      den.aspects.core.persist-collector
      den.aspects.core.persist-home-collector
    ];

    settings = {
      wipeRootOnBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Rollback ZFS root to @empty on boot";
      };
      wipeHomeOnBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Rollback ZFS home to @empty on boot";
      };
    };

    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        wipeRoot = host.settings.disk.impermanence.wipeRootOnBoot;
        wipeHome = host.settings.disk.impermanence.wipeHomeOnBoot;
      in
      {
        imports = [
          inputs.impermanence.nixosModules.impermanence
        ];

        options.impermanence.ignorePaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Paths ignored by persistence diff tooling.";
        };

        config = {
          impermanence.ignorePaths = [
            "/etc/NIXOS"
            "/etc/.clean"
            "/etc/.updated"
            "/etc/.pwd.lock"
            "/var/.updated"
            "/etc/subgid"
            "/etc/subuid"
            "/etc/shadow"
            "/etc/group"
            "/etc/passwd"
            "/root/.nix-channels"
            "/var/lib/systemd/linger/"
            "/var/lib/systemd/random-seed"
            "/etc/fwupd/fwupd.conf"
            "/var/lib/tpm2-udev-trigger/hash.txt"
            "/etc/ssh/authorized_keys.d/"
          ];

          # Fix /var/lib and /var/lib/private permissions after impermanence creates them
          system.activationScripts."var-lib-private-perms" = {
            deps = [
              "persist-files"
              "createPersistentStorageDirs"
            ];
            text = ''
              mkdir -p /var/lib/private
              chown root:root /var/lib
              chmod 0755 /var/lib
              chown root:root /var/lib/private
              chmod 0700 /var/lib/private
            '';
          };

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

          environment.persistence = {
            "/cache" = {
              enable = true;
              persistentStoragePath = "/cache";
              hideMounts = true;
              directories = [
                "/var/lib/nixos"
                "/var/tmp"
                "/srv"
              ];
            };

            "/persist" = {
              enable = true;
              hideMounts = true;
              directories = [ ];
              files = [
                "/etc/machine-id"
                "/etc/zfs/zpool.cache"
                "/etc/adjtime"
                "/root/.bash_history"
              ];
            };
          };
        };
      };

    # Home Manager persistence
    homeManager = {
      home.persistence = {
        "/persist" = {
          directories = [
            "Desktop"
            "Documents"
            "Music"
            "Pictures"
            "Public"
            "Templates"
            "Videos"
            {
              directory = ".ssh";
              mode = "0700";
            }
            {
              directory = ".local/share/keyrings";
              mode = "0700";
            }
          ];
        };

        "/cache" = {
          directories = [
            "Downloads"
            ".local/share/direnv"
            ".local/share/nix"
            ".cache"
          ];
        };
      };
    };
  };
}

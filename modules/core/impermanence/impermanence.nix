{ inputs, ... }:
{
  flake.features.impermanence.nixos =
    {
      lib,
      config,
      pkgs,
      activeFeatures,
      ...
    }:
    with lib;
    with builtins;
    let
      zfsEnabled = lib.elem "zfs" activeFeatures;
      btrfsEnabled = lib.elem "btrfs" activeFeatures;
      cfg = config.impermanence;
    in
    {
      # imports = [
      #   inputs.impermanence.nixosModules.impermanence
      # ];

      options.impermanence = with lib.types; {
        enable = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Enable impermanence features.";
        };
        wipeRootOnBoot = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Enable root rollback on boot.";
        };
        wipeHomeOnBoot = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Enable home rollback on boot.";
        };
      };

      config = {
        environment.persistence = {
          "/volatile" = {
            enable = cfg.enable;
            hideMounts = true;
            directories = [
              "/var/lib/nixos"
              "/var/tmp"
              "/srv"
            ];
          };
          "/persist" = {
            enable = cfg.enable;
            hideMounts = true;
            directories = [ ];
            files = [
              "/etc/machine-id"
              "/etc/adjtime"

              # SSH host keys needed for remote access and agenix
              "/etc/ssh/ssh_host_ed25519_key"
              "/etc/ssh/ssh_host_ed25519_key.pub"
              "/etc/ssh/ssh_host_rsa_key"
              "/etc/ssh/ssh_host_rsa_key.pub"
            ];
          };
        };

        home-manager.sharedModules = [
          {
            options.home.persistence = mkOption {
              description = "Additional persistence config for the given source path";
              default = { };
              type = types.attrsOf (
                types.submodule {
                  options = {
                    files = mkOption {
                      description = "Additional files to persist via NixOS impermanence.";
                      type = types.listOf (types.either types.attrs types.str);
                      default = [ ];
                    };

                    directories = mkOption {
                      description = "Additional directories to persist via NixOS impermanence.";
                      type = types.listOf (types.either types.attrs types.str);
                      default = [ ];
                    };
                  };
                }
              );
            };
          }
        ];

        # For each user that has a home-manager config, merge the locally defined
        # persistence options that we defined above.
        imports =
          let
            mkUserFiles = map (
              x: { parentDirectory.mode = "700"; } // (if isAttrs x then x else { file = x; })
            );
            mkUserDirs = map (x: { mode = "700"; } // (if isAttrs x then x else { directory = x; }));
          in
          [
            inputs.impermanence.nixosModules.impermanence
            {
              environment.persistence = mkMerge (
                flip map (attrNames config.home-manager.users) (
                  user:
                  let
                    hmUserCfg = config.home-manager.users.${user};
                  in
                  flip mapAttrs hmUserCfg.home.persistence (
                    _: sourceCfg: {
                      users.${user} = {
                        files = mkUserFiles sourceCfg.files;
                        directories = mkUserDirs sourceCfg.directories;
                      };
                    }
                  )
                )
              );
            }
          ];

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
            "local/volatile" = {
              type = "zfs_fs";
              options.mountpoint = "legacy";
              mountpoint = "/volatile";
              options."com.sun:auto-snapshot" = "true";
              postCreateHook = "zfs snapshot zroot/local/volatile@empty";
            };
          };
        };
      }
      // lib.optionalAttrs cfg.enable {
        fileSystems = {
          "/persist".neededForBoot = true;
          "/volatile".neededForBoot = true;
        };

        boot.initrd.systemd.services =
          lib.optionalAttrs cfg.wipeRootOnBoot {
            rollback-zfs-root = lib.mkIf zfsEnabled {
              description = "Rollback ZFS root dataset to a pristine state";
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
            rollback-btrfs-root = lib.mkIf btrfsEnabled {
              description = "Rollback BTRFS root subvolume to a pristine state";
              wantedBy = [ "initrd.target" ];
              # make sure it's done after encryption
              # i.e. LUKS/TPM process
              after = [ "systemd-cryptsetup@cryptroot.service" ];
              # mount the root fs before clearing
              before = [ "sysroot.mount" ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = ''
                mkdir -p /mnt

                # We first mount the btrfs root to /mnt
                # so we can manipulate btrfs subvolumes.
                mount -o subvol=/ /dev/mapper/cryptroot /mnt
                btrfs subvolume list -o /mnt/root

                # While we're tempted to just delete /root and create
                # a new snapshot from /root-blank, /root is already
                # populated at this point with a number of subvolumes,
                # which makes `btrfs subvolume delete` fail.
                # So, we remove them first.
                #
                # /root contains subvolumes:
                # - /root/var/lib/portables
                # - /root/var/lib/machines

                btrfs subvolume list -o /mnt/root |
                cut -f9 -d' ' |
                while read subvolume; do
                  echo "deleting /$subvolume subvolume..."
                  btrfs subvolume delete "/mnt/$subvolume"
                done &&
                echo "deleting /root subvolume..." &&
                btrfs subvolume delete /mnt/root

                echo "restoring blank /root subvolume..."
                btrfs subvolume snapshot /mnt/root-blank /mnt/root

                # Once we're done rolling back to a blank snapshot,
                # we can unmount /mnt and continue on the boot process.
                umount /mnt
              '';
            };
          }
          // lib.optionalAttrs cfg.wipeHomeOnBoot {
            # Rollback '/home'
            rollback-zfs-home = lib.mkIf zfsEnabled {
              description = "Rollback ZFS home dataset to a pristine state";
              wantedBy = [ "initrd.target" ];
              after = [ "zfs-import-zroot.service" ];
              before = [ "-.mount" ];
              path = with pkgs; [ zfs_cachyos ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = ''
                zfs rollback -r zroot/local/home@empty && echo "rollback complete"
              '';
            };
            # rollback-btrfs-home = lib.mkIf btrfsEnabled {
            #   description = "Rollback BTRFS root subvolume to a pristine state";
            #   wantedBy = [ "initrd.target" ];
            #   # make sure it's done after encryption
            #   # i.e. LUKS/TPM process
            #   after = [ "systemd-cryptsetup@cryptroot.service" ];
            #   # mount the root fs before clearing
            #   before = [ "home.mount" ];
            #   unitConfig.DefaultDependencies = "no";
            #   serviceConfig.Type = "oneshot";
            #   script = ''
            #     mkdir -p /mnt
            #     mount -o subvol=/home /dev/mapper/cryptroot /mnt

            #     # We first mount the btrfs root to /mnt
            #     # so we can manipulate btrfs subvolumes.
            #     mount -o subvol=/ /dev/mapper/cryptroot /mnt
            #     btrfs subvolume list -o /mnt/root

            #     # While we're tempted to just delete /root and create
            #     # a new snapshot from /root-blank, /root is already
            #     # populated at this point with a number of subvolumes,
            #     # which makes `btrfs subvolume delete` fail.
            #     # So, we remove them first.
            #     #
            #     # /root contains subvolumes:
            #     # - /root/var/lib/portables
            #     # - /root/var/lib/machines

            #     btrfs subvolume list -o /mnt/root |
            #     cut -f9 -d' ' |
            #     while read subvolume; do
            #       echo "deleting /$subvolume subvolume..."
            #       btrfs subvolume delete "/mnt/$subvolume"
            #     done &&
            #     echo "deleting /root subvolume..." &&
            #     btrfs subvolume delete /mnt/root

            #     echo "restoring blank /root subvolume..."
            #     btrfs subvolume snapshot /mnt/root-blank /mnt/root

            #     # Once we're done rolling back to a blank snapshot,
            #     # we can unmount /mnt and continue on the boot process.
            #     umount /mnt
            #   '';
            # };
          };

        systemd = {
          tmpfiles.settings."persistent-dirs" =
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
                  "/volatile/${user.home}" = {
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
        }
        // lib.optionalAttrs zfsEnabled {
          # Take snapshots before shutdown for recovery, then rollback to empty
          shutdownRamfs.contents."/etc/systemd/system-shutdown/zpool".source = lib.mkForce (
            pkgs.writeShellScript "zpool-sync-shutdown" ''
              # Remove existing lastboot snapshots if they exist
              ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/root@lastboot" 2>/dev/null || true
              ${config.boot.zfs.package}/bin/zfs destroy "zroot/local/home@lastboot" 2>/dev/null || true

              # Take new lastboot snapshots for recovery
              ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/root@lastboot"
              ${config.boot.zfs.package}/bin/zfs snapshot "zroot/local/home@lastboot"

              # Rollback to empty state
              ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/root@empty"
              ${config.boot.zfs.package}/bin/zfs rollback -r "zroot/local/home@empty"

              # Sync the pool before shutdown
              exec ${config.boot.zfs.package}/bin/zpool sync
            ''
          );

          shutdownRamfs.storePaths = [ "${config.boot.zfs.package}/bin/zfs" ];
        };

        # Needed for home-manager's impermanence allowOther option to work
        programs.fuse.userAllowOther = true;
      };
    };
}

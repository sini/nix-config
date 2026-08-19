{
  den,
  lib,
  inputs,
  ...
}:
{
  # ZFS root support aspect (packages, kernel params, services)
  den.aspects.disk.zfs-disk-single.root = {
    includes = [ den.aspects.disk.zfs-diff ];

    nixos =
      { config, pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.lzop
          pkgs.mbuffer
          pkgs.pv
        ];

        boot = {
          supportedFilesystems.zfs = true;

          zfs = {
            package = config.boot.kernelPackages.zfs_cachyos;
            devNodes = "/dev/disk/by-id/";
            forceImportRoot = true;
            forceImportAll = true;
            requestEncryptionCredentials = [ "zroot" ];
          };

          kernelParams = [
            "zfs.zfs_arc_max=${toString (16 * 1024 * 1024 * 1024)}"
            # Cloning a range whose source blocks are still dirty makes
            # zfs_clone_range() wait on a full txg sync and retry
            # (module/zfs/zfs_vnops.c: the EAGAIN arm calling
            # txg_wait_synced_flags). Nix and coreutils >= 9 reach that path
            # constantly via copy_file_range, so on a busy pool every writer on
            # the host serialises behind one sync and stalls long enough to trip
            # the systemd watchdogs. With the wait off, the clone returns a
            # short range and the caller falls back to a plain copy; cloning
            # still applies to blocks that are already on disk.
            "zfs.zfs_bclone_wait_dirty=0"
            "elevator=none"
            "nohibernate"
          ];
        };

        systemd.services.systemd-udev-settle.enable = false;

        services.zfs = {
          expandOnBoot = "all";
          autoScrub.enable = true;
          autoScrub.interval = "weekly";
          trim.enable = true;
        };
      };
  };

  # ZFS single-disk disko layout
  den.aspects.disk.zfs-disk-single = {
    includes = [ den.aspects.disk.zfs-disk-single.root ];

    settings = {
      device_id = lib.mkOption {
        type = lib.types.str;
        description = "Disk device path for ZFS pool (e.g., /dev/disk/by-id/nvme-...)";
      };
    };

    nixos =
      {
        config,
        host,
        ...
      }:
      let
        disk-device = host.settings.disk.zfs-disk-single.device_id;

        emptySnapshot =
          name: "zfs list -t snapshot -H -o name | grep -E '^${name}@empty$' || zfs snapshot ${name}@empty";

        # Retired: support for provision-zfs-datasets (commented out below).
        # Kept for reference should a future dataset need the same rollout.
        #
        # zfsDatasets = config.disko.devices.zpool.zroot.datasets;
        #
        # foundationalMounts = [
        #   "/"
        #   "/nix"
        #   "/home"
        #   "/persist"
        #   "/cache"
        #   "/boot"
        # ];
        # provisionable = lib.filterAttrs (
        #   _name: ds: ds.mountpoint != null && !(lib.elem ds.mountpoint foundationalMounts)
        # ) zfsDatasets;
        #
        # mountUnit = path: "${lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" path)}.mount";
        #
        # Pools predating rootFsOptions.normalization = "none" still carry formD
        # (and the utf8only=on it forces) on their root dataset, and both are
        # create-time only, so anything provisioned on such a pool inherits them
        # for good. A child may override its parent; only the pool root is stuck.
        # unicodeOptions = {
        #   normalization = "none";
        #   utf8only = "off";
        # };
        # mkOpts =
        #   ds:
        #   lib.concatStringsSep " " (
        #     lib.mapAttrsToList (k: v: "-o ${k}=${toString v}") (unicodeOptions // ds.options)
        #   );
        # provisionMounts = lib.mapAttrsToList (_name: ds: mountUnit ds.mountpoint) provisionable;
      in
      {
        imports = [ inputs.disko.nixosModules.default ];

        # Retired rollout provisioner, kept for reference.
        #
        # disko only creates datasets at install, yet it emits a *required*
        # fileSystems mount for each at every switch, so adding a dataset to the
        # layout would fail to boot on pools created earlier. This unit created
        # any missing data dataset after the pool imported and before its mount
        # ran. Every deployed pool now carries the full layout, so it is dead
        # weight.
        #
        # Two traps if it is ever reinstated. DefaultDependencies must stay off:
        # default deps add After=basic.target, which (being after local-fs.target)
        # forms a cycle with Before=<dataset>.mount and makes systemd delete mount
        # jobs nondeterministically — datasets then mount on some boots, not
        # others. And requiredBy puts Requires= on each data mount, which systemd
        # propagates: any switch that changes this unit's text stops it and takes
        # those mounts down with it, unmounting containerd's data root under a
        # running containerd. Prefer wantedBy, which keeps the Before= ordering
        # without the propagation.
        #
        # systemd.services.provision-zfs-datasets = {
        #   description = "Create declared zfs datasets missing on pre-existing pools";
        #   unitConfig.DefaultDependencies = false;
        #   after = [ "zfs-import-zroot.service" ];
        #   before = provisionMounts ++ [ "shutdown.target" ];
        #   conflicts = [ "shutdown.target" ];
        #   requiredBy = provisionMounts;
        #   path = [ config.boot.zfs.package ];
        #   serviceConfig = {
        #     Type = "oneshot";
        #     RemainAfterExit = true;
        #   };
        #   script = lib.concatStringsSep "\n" (
        #     lib.mapAttrsToList (
        #       name: ds:
        #       "zfs list -H -o name zroot/${name} >/dev/null 2>&1 || zfs create ${mkOpts ds} zroot/${name}"
        #     ) provisionable
        #   );
        # };

        disko.devices = {
          disk.disk0 = {
            type = "disk";
            device = disk-device;
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  type = "EF00";
                  size = "500M";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [ "umask=077" ];
                  };
                };
                root = {
                  size = "100%";
                  content = {
                    type = "zfs";
                    pool = "zroot";
                  };
                };
              };
            };
          };
          zpool.zroot = {
            type = "zpool";
            options = {
              ashift = "12";
              autotrim = "on";
            };

            rootFsOptions = {
              acltype = "posixacl";
              canmount = "off";
              # blake3 over edonr: OpenZFS ships no SIMD implementation of edonr
              # at all, so it runs scalar everywhere, while blake3 has avx2 and
              # avx512 paths. Every host in the fleet has at least avx2, which is
              # the crossover (measured on cortex, 64k blocks: edonr 2325 MB/s,
              # blake3-avx2 3831, blake3-avx512 8552; blake3 loses below avx2).
              # Encryption does not bypass it — an encrypted block's checksum is
              # 128 bits of this algorithm plus 128 bits of AEAD MAC.
              # Note the pool feature is not read-only compatible: once a blake3
              # block is written the pool needs OpenZFS >= 2.2 to import at all,
              # so rescue media older than that stops working.
              checksum = "blake3";
              compression = "zstd";
              dnodesize = "auto";
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              keylocation = "file:///tmp/secret.key";
              mountpoint = "none";
              # Byte-exact filenames, as on every other Linux filesystem. Any
              # normalization other than "none" forces utf8only=on, and utf8only
              # makes the kernel reject filenames that are not valid UTF-8 with
              # EILSEQ instead of creating them: package test suites that build
              # such names fail (python pygit2), and OCI layers carrying them
              # fail to unpack. formD additionally makes lookups
              # normalization-insensitive, so NFC and NFD spellings of one name
              # collide and a tree containing both cannot be checked out.
              # Both are create-time only and cannot be set on zfs receive, so
              # getting this wrong costs a dataset rebuild.
              normalization = "none";
              utf8only = "off";
              relatime = "on";
              xattr = "sa";
              "com.sun:auto-snapshot" = "false";
            };

            postCreateHook = ''
              zfs set keylocation="prompt" $name;
              if ! zfs list -t snap zroot/local/root@empty; then
                  zfs snapshot zroot/local/root@empty
              fi
            '';

            datasets = {
              "reserved" = {
                type = "zfs_fs";
                options = {
                  mountpoint = "none";
                  canmount = "off";
                  reservation = "10G";
                  "com.sun:auto-snapshot" = "false";
                };
              };
              "local/root" = {
                mountpoint = "/";
                type = "zfs_fs";
                options.mountpoint = "legacy";
                postCreateHook = ''
                  zfs snapshot zroot/local/root@empty;
                  zfs snapshot zroot/local/root@lastboot;
                '';
              };
              "local/nix" = {
                type = "zfs_fs";
                options.mountpoint = "legacy";
                mountpoint = "/nix";
                options = {
                  atime = "off";
                  canmount = "on";
                  compression = "zstd";
                  "com.sun:auto-snapshot" = "true";
                };
                postCreateHook = emptySnapshot "zroot/local/nix";
              };
              "local/home" = {
                type = "zfs_fs";
                options.mountpoint = "legacy";
                mountpoint = "/home";
                options."com.sun:auto-snapshot" = "true";
                postCreateHook = ''
                  zfs snapshot zroot/local/home@empty;
                  zfs snapshot zroot/local/home@lastboot
                '';
              };
              "local/persist" = {
                type = "zfs_fs";
                options.mountpoint = "legacy";
                mountpoint = "/persist";
                options."com.sun:auto-snapshot" = "true";
                postCreateHook = emptySnapshot "zroot/local/persist";
              };
              "local/cache" = {
                type = "zfs_fs";
                options.mountpoint = "legacy";
                mountpoint = "/cache";
                options."com.sun:auto-snapshot" = "true";
                postCreateHook = emptySnapshot "zroot/local/cache";
              };
              "local/containers" = {
                type = "zfs_fs";
                mountpoint = "/cache/var/lib/containers";
                options = {
                  mountpoint = "legacy";
                  atime = "off";
                  recordsize = "128K";
                  "com.sun:auto-snapshot" = "true";
                };
                postCreateHook = emptySnapshot "zroot/local/containers";
              };
              # containerd data root (k3s nodes): content store + metadata,
              # persisted across the impermanence wipe. New on already-deployed
              # pools, so provision-zfs-datasets (above) creates it pre-mount.
              "local/containerd" = {
                type = "zfs_fs";
                mountpoint = "/var/lib/containerd";
                options = {
                  mountpoint = "legacy";
                  atime = "off";
                  recordsize = "128K";
                  "com.sun:auto-snapshot" = "true";
                };
                postCreateHook = emptySnapshot "zroot/local/containerd";
              };
              # The zfs snapshotter requires its root to BE a zfs dataset
              # mountpoint (not merely on a zfs fs), so it gets a dedicated child
              # dataset at exactly the plugin path. The snapshotter creates a CoW
              # child dataset per image layer under it — don't auto-snapshot that
              # churn.
              "local/containerd/snapshotter" = {
                type = "zfs_fs";
                mountpoint = "/var/lib/containerd/io.containerd.snapshotter.v1.zfs";
                options = {
                  mountpoint = "legacy";
                  atime = "off";
                  recordsize = "128K";
                  "com.sun:auto-snapshot" = "false";
                };
              };
              "local/libvirt-images" = {
                type = "zfs_fs";
                mountpoint = "/persist/var/lib/libvirt/images";
                options = {
                  mountpoint = "legacy";
                  atime = "off";
                  recordsize = "64K";
                  compression = "lz4";
                  "com.sun:auto-snapshot" = "true";
                };
                postCreateHook = emptySnapshot "zroot/local/libvirt-images";
              };
            };
          };
        };

        fileSystems = {
          "/" = {
            device = "zroot/local/root";
            fsType = "zfs";
            neededForBoot = true;
          };
          "/nix" = {
            device = "zroot/local/nix";
            fsType = "zfs";
            neededForBoot = true;
          };
          "/home" = {
            device = "zroot/local/home";
            fsType = "zfs";
            neededForBoot = true;
          };
          "/persist" = {
            device = "zroot/local/persist";
            fsType = "zfs";
            neededForBoot = true;
          };
          "/cache" = {
            device = "zroot/local/cache";
            fsType = "zfs";
            neededForBoot = true;
          };
        };
      };
  };
}

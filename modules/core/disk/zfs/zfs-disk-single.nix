# Luks2 encrypted disk with btrfs subvolumes, depends on facter report
{ inputs, ... }:
{
  flake.features.zfs-disk-single = {
    requires = [ "zfs" ];
    nixos =
      {
        config,
        lib,
        ...
      }:
      with lib;

      let
        cfg = config.hardware.disk.zfs-disk-single;
        disk-device =
          let
            # Filter out USB storage devices as invalid candidates
            native-disks = builtins.filter (f: f.driver != "usb-storage") config.facter.report.hardware.disk;

            # Extract /dev/disk/by-id/ paths, with error handling
            disk-labels = builtins.filter (label: label != null) (
              map (
                disk:
                let
                  by-id-paths = builtins.filter (
                    f: builtins.substring 0 16 f == "/dev/disk/by-id/"
                  ) disk.unix_device_names;
                in
                if builtins.length by-id-paths > 0 then builtins.head by-id-paths else null
              ) native-disks
            );
          in
          if (builtins.length disk-labels == 0) then
            abort (
              "No suitable disks found. Please specify hardware.disk.zfs-disk-single.device_id manually. "
              + "Check that your disk has /dev/disk/by-id/ entries and is not USB."
            )
          else if (builtins.length disk-labels == 1) then
            (builtins.head disk-labels)
          else
            abort (
              "Multiple disks found. Please specify hardware.disk.zfs-disk-single.device_id. Found: "
              + builtins.toString disk-labels
            );

        emptySnapshot =
          name: "zfs list -t snapshot -H -o name | grep -E '^${name}@empty$' || zfs snapshot ${name}@empty";
      in
      {
        imports = [ inputs.disko.nixosModules.default ];

        options.hardware.disk.zfs-disk-single = with lib.types; {
          device_id = mkOption {
            type = str;
            default = disk-device;
            description = ''
              (Optional) Disk device id (e.g., "ata-...").
              If not set, the module attempts to find a single non-USB disk.
              If multiple disks are found or none are found, evaluation will abort
              and this option must be set manually.
            '';
          };
        };

        # config = mkIf cfg.enable { # Removed mkIf condition
        config = {
          disko.devices = {
            disk.disk0 = {
              type = "disk";
              device = cfg.device_id;
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
                ashift = "12"; # 4K sector alignment
                autotrim = "on"; # Helps SSD longevity
              };

              rootFsOptions = {
                acltype = "posixacl"; # Enable POSIX ACLs for fine-grained permissions
                canmount = "off"; # Don't mount the root dataset directly
                checksum = "edonr"; # Fast, strong checksum
                compression = "zstd"; # Better compression ratio than lz4, still fast
                dnodesize = "auto"; # Allow variable dnode sizes
                encryption = "aes-256-gcm"; # Explicit AES-GCM encryption
                keyformat = "passphrase"; # Key derived from passphrase
                keylocation = "file:///tmp/secret.key"; # Temporary key file during install
                mountpoint = "none"; # Don't mount the root dataset itself
                normalization = "formD"; # Unicode normalization (macOS/Nix-safe)
                relatime = "on"; # Reduce atime writes
                xattr = "sa"; # Store xattrs in system attributes for speed
                "com.sun:auto-snapshot" = "false"; # Disable auto-snapshotting
              };

              postCreateHook = ''
                zfs set keylocation="prompt" $name;
                if ! zfs list -t snap zroot/local/root@empty; then
                    zfs snapshot zroot/local/root@empty
                fi
              '';

              # to prevent mounting after multi-user.target, which can lead to mishaps
              # (creating files before mounting), all datasets are mounted declaratively
              # via config. to achieve this we set options.mountpoint = "legacy" and
              # disable zfs-mount.service
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
                  # TODO: Do we need home on a separate dataset if we're doing user impermenance?
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
  };
}

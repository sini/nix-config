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
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.lzop
          pkgs.mbuffer
          pkgs.pv
        ];

        boot = {
          supportedFilesystems.zfs = true;

          zfs = {
            package = pkgs.zfs_2_4;
            devNodes = "/dev/disk/by-id/";
            forceImportAll = true;
            requestEncryptionCredentials = [ "zroot" ];
          };

          kernelParams = [
            "zfs.zfs_arc_max=${toString (16 * 1024 * 1024 * 1024)}"
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
      { host, ... }:
      let
        disk-device = host.settings.disk.zfs-disk-single.device_id;

        emptySnapshot =
          name: "zfs list -t snapshot -H -o name | grep -E '^${name}@empty$' || zfs snapshot ${name}@empty";
      in
      {
        imports = [ inputs.disko.nixosModules.default ];

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
              checksum = "edonr";
              compression = "zstd";
              dnodesize = "auto";
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              keylocation = "file:///tmp/secret.key";
              mountpoint = "none";
              normalization = "formD";
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

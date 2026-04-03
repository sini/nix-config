# Disko ZFS layout: single disk, encryption, datasets
{ den, lib, ... }:
{
  den.aspects.zfs-disk-single = {
    includes = [
      den.aspects.zfs-root
    ]
    ++ lib.attrValues den.aspects.zfs-disk-single._;

    _ = {
      layout = den.lib.perHost (
        { host }:
        {
          nixos =
            { config, ... }:
            let
              # Read device from typed schema; null means auto-detect via facter
              disk-device =
                if host.settings.zfs-disk-single.device_id != null then
                  host.settings.zfs-disk-single.device_id
                else
                  let
                    native-disks = builtins.filter (f: f.driver != "usb-storage") config.facter.report.hardware.disk;

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
                      "No suitable disks found. Please set host.settings.zfs-disk-single.device_id. "
                      + "Check that your disk has /dev/disk/by-id/ entries and is not USB."
                    )
                  else if (builtins.length disk-labels == 1) then
                    (builtins.head disk-labels)
                  else
                    abort (
                      "Multiple disks found. Please set host.settings.zfs-disk-single.device_id. Found: "
                      + toString disk-labels
                    );

              emptySnapshot =
                name: "zfs list -t snapshot -H -o name | grep -E '^${name}@empty$' || zfs snapshot ${name}@empty";
            in
            {
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
        }
      );
    };
  };
}

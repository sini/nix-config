# Disko BTRFS layout: single disk, LUKS encryption, subvolumes
{ den, lib, ... }:
{
  den.aspects.btrfs-disk-single = {
    includes = [
      den.aspects.btrfs-root
    ]
    ++ lib.attrValues den.aspects.btrfs-disk-single._;

    _ = {
      layout = den.lib.perHost (
        { host }:
        {
          nixos =
            { config, lib, ... }:
            let
              # Read device from typed schema; null means auto-detect via facter
              rawDevice = host.settings.btrfs-disk-single.device_id;
              swapSize = host.settings.btrfs-disk-single.swap_size;

              disk-device =
                if rawDevice != null then
                  if lib.hasPrefix "/dev/" rawDevice then rawDevice else "/dev/disk/by-id/" + rawDevice
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
                  if (builtins.length disk-labels == 1) then
                    (builtins.head disk-labels)
                  else
                    abort (
                      "Multiple or no disks found. Please set host.settings.btrfs-disk-single.device_id. Found: "
                      + toString disk-labels
                    );

              defaultBtrfsOpts = [
                "defaults"
                "compress=zstd:1"
                "ssd"
                "discard=async"
                "noatime"
                "nodiratime"
              ];
            in
            {
              disko.devices = {
                disk = {
                  main = {
                    device = disk-device;
                    type = "disk";
                    content = {
                      type = "gpt";
                      partitions = {
                        ESP = {
                          label = "boot";
                          name = "ESP";
                          size = "512M";
                          type = "EF00";
                          content = {
                            type = "filesystem";
                            format = "vfat";
                            mountpoint = "/boot";
                            mountOptions = [ "defaults" ];
                          };
                        };
                        luks = {
                          size = "100%";
                          label = "luks";
                          content = {
                            type = "luks";
                            name = "cryptroot";
                            passwordFile = "/tmp/secret.key";
                            extraOpenArgs = [
                              "--allow-discards"
                              "--perf-no_read_workqueue"
                              "--perf-no_write_workqueue"
                            ];
                            settings = {
                              crypttabExtraOpts = [
                                "tpm2-device=auto"
                                "fido2-device=auto"
                                "token-timeout=10"
                              ];
                            };
                            content = {
                              type = "btrfs";
                              extraArgs = [
                                "-L"
                                "nixos"
                                "-f"
                              ];
                              postCreateHook = ''
                                mount -t btrfs /dev/disk/by-label/nixos /mnt
                                btrfs subvolume snapshot -r /mnt/root /mnt/root-blank
                                btrfs subvolume snapshot -r /mnt/home /mnt/home-blank
                                umount /mnt
                              '';
                              subvolumes = {
                                "/root" = {
                                  mountpoint = "/";
                                  mountOptions = defaultBtrfsOpts;
                                };
                                "/home" = {
                                  mountpoint = "/home";
                                  mountOptions = defaultBtrfsOpts;
                                };
                                "/nix" = {
                                  mountpoint = "/nix";
                                  mountOptions = defaultBtrfsOpts;
                                };
                                "/persist" = {
                                  mountpoint = "/persist";
                                  mountOptions = defaultBtrfsOpts;
                                };
                                "/cache" = {
                                  mountpoint = "/cache";
                                  mountOptions = defaultBtrfsOpts;
                                };
                              }
                              // lib.optionalAttrs (swapSize != "0") {
                                "@swap" = {
                                  mountpoint = "/swap";
                                  swap.swapfile.size = swapSize;
                                };
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                };
              };
              fileSystems = {
                "/nix".neededForBoot = true;
                "/home".neededForBoot = true;
                "/persist".neededForBoot = true;
                "/cache".neededForBoot = true;
              };
            };
        }
      );
    };
  };
}

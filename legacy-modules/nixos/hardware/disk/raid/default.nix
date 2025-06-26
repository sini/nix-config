# Luks2 encrypted disk with disk-spanning btrfs subvolumes
# Note: Swap is not supported on multi-disk btrfs systems
{
  lib,
  inputs,
  config,
  ...
}:
with lib;
with lib.custom;
let
  cfg = config.hardware.disk.raid;

  # Filter out USB storage devices as invalid candidates
  native-disks = builtins.filter (f: f.driver != "usb-storage") config.facter.report.hardware.disk;
  sorted-disks = builtins.sort (a: b: a.sysfs_device_link < b.sysfs_device_link) native-disks;
  # Disks are sorted by their sysfs_device_link -- it's PCI address, which should be static
  # unless the disk is moved to a different location. This should not occur unless
  # there is a hardware failure. We do not do local disk redundancy -- we rely on backups
  # or distributed filesystems.
  disk-labels =
    builtins.map
      (
        disk:
        builtins.head (
          builtins.filter (f: builtins.substring 0 16 f == "/dev/disk/by-id/") disk.unix_device_names
        )
      )
      (
        if (cfg.boot_device != "") then
          (builtins.filter (d: !(builtins.elem cfg.boot_device d.unix_device_names)) sorted-disks)
        else
          sorted-disks
      );
  boot_disk =
    if (cfg.boot_device != "") then
      (
        if (builtins.length disk-labels < builtins.length sorted-disks) then
          cfg.boot_device
        else
          abort "Specified boot disk not found, found: " + builtins.toString disk-labels
      )
    else
      (builtins.head disk-labels);
  data_disks =
    if (cfg.data_disks == [ ]) then
      (
        # Verify the boot disk is in the list of disks
        if (builtins.elem boot_disk disk-labels) then
          builtins.filter (d: d != boot_disk) disk-labels
        else
          abort "Specified boot disk not found, found: " + builtins.toString disk-labels
      )
    else
      cfg.data_disks;

  # Ensure the boot disk is the first disk, lets build
  ordered_disks = [ boot_disk ] ++ data_disks;

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
  imports = [ inputs.disko.nixosModules.default ];

  options.hardware.disk.raid = with types; {
    enable = mkBoolOpt false "Whether or not to configure disk.";
    boot_device = mkOption {
      type = types.str;
      default = "";
      description = "(Optional) Disk device ID to use for root.";
    };
    data_disks = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of disk device IDs to use for data.";
    };
    btrfs_profile = mkOption {
      type = types.str;
      default = "single";
      description = "Btrfs profile to use for data. ex: single, raid0, raid1, raid10, raid5, raid6, dup.";
    };
  };
  # Derived from https://github.com/nix-community/disko/blob/master/example/luks-btrfs-raid.nix
  # and https://github.com/nix-community/disko/blob/master/example/luks-btrfs-subvolumes.nix
  config = mkIf cfg.enable {
    disko.devices = {
      disk = lib.attrsets.mergeAttrsList (
        lib.lists.imap1 (i: device_id: {
          "disk${toString i}" = {
            device = device_id;
            type = "disk";
            content = {
              type = "gpt";
              partitions =
                lib.optionalAttrs (device_id == boot_disk) {
                  ESP = {
                    label = "boot";
                    name = "ESP";
                    size = "512M";
                    type = "EF00";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                      mountOptions = [
                        "defaults"
                      ];
                    };
                  };
                }
                // {
                  "crypt${toString i}" = {
                    size = "100%";
                    content =
                      {
                        type = "luks";
                        name = "crypt${toString i}"; # device-mapper name when decrypted
                        # Remove settings.keyFile if you want to use interactive password entry
                        extraOpenArgs = [
                          "--allow-discards"
                          "--perf-no_read_workqueue"
                          "--perf-no_write_workqueue"
                        ];
                        # https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html
                        settings = {
                          allowDiscards = true;
                          crypttabExtraOpts = [
                            "tpm2-device=auto"
                            "fido2-device=auto"
                            "token-timeout=10"
                          ];
                        };
                      }
                      // lib.optionalAttrs (i == builtins.length ordered_disks) {
                        content = {
                          type = "btrfs";
                          extraArgs =
                            [
                              "-L"
                              "nixos"
                              "-m raid1" # Mirror metadata
                              "-d ${cfg.btrfs_profile}" # Single copy for data
                              "-f"
                            ]
                            ++ builtins.map (idx: "/dev/mapper/crypt${toString idx}") (
                              lib.lists.range 1 (builtins.length ordered_disks)
                            );
                          subvolumes = {
                            "@" = {
                              mountpoint = "/";
                              mountOptions = defaultBtrfsOpts;
                            };
                            "@home" = {
                              mountpoint = "/home";
                              mountOptions = defaultBtrfsOpts;
                            };
                            "@nix" = {
                              mountpoint = "/nix";
                              mountOptions = defaultBtrfsOpts;
                            };
                            "@persist" = {
                              mountpoint = "/persist";
                              mountOptions = defaultBtrfsOpts;
                            };
                            "@log" = {
                              mountpoint = "/var/log";
                              mountOptions = defaultBtrfsOpts;
                            };
                          };
                        };
                      };
                  };
                };
            };
          };
        }) ordered_disks
      );
    };

    fileSystems."/persist".neededForBoot = true;
    fileSystems."/var/log".neededForBoot = true;

  };
}

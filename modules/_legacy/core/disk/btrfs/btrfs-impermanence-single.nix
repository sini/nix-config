# Luks2 encrypted disk with btrfs subvolumes, depends on facter report
{ inputs, lib, ... }:
{
  features.btrfs-impermanence-single = {
    requires = [ "btrfs-root" ];

    settings = {
      device_id = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Disk device id (e.g., "ata-..." or "/dev/disk/by-id/...").
          If not set, the module attempts to find a single non-USB disk
          via facter. Aborts if multiple or no disks are found.
        '';
      };
      swap_size = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Size of swap in MiB, 0 disables swap.";
      };
    };

    linux =
      {
        config,
        lib,
        settings,
        ...
      }:

      let
        cfg = settings.btrfs-impermanence-single;

        # Use setting if provided, otherwise auto-detect from facter
        disk-device =
          if cfg.device_id != "" then
            if lib.hasPrefix "/dev/" cfg.device_id then cfg.device_id else "/dev/disk/by-id/" + cfg.device_id
          else
            let
              # Filter out USB storage devices as invalid candidates
              native-disks = builtins.filter (f: f.driver != "usb-storage") config.facter.report.hardware.disk;
              disk-labels = map (
                disk:
                builtins.head (
                  builtins.filter (f: builtins.substring 0 16 f == "/dev/disk/by-id/") disk.unix_device_names
                )
              ) native-disks;
            in
            if (builtins.length disk-labels == 1) then
              (builtins.head disk-labels)
            else
              abort (
                "Multiple disks found. Please set settings.btrfs-impermanence-single.device_id. Found: "
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
        imports = [ inputs.disko.nixosModules.default ];

        config = {
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
                          // lib.optionalAttrs (cfg.swap_size > 0) {
                            "@swap" = {
                              mountpoint = "/swap";
                              swap.swapfile.size = "${toString cfg.swap_size}M";
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
      };
  };
}

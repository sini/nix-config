# NixOS module for configuring OS drive (encrypted Btrfs) and a dedicated Longhorn data drive.
{
  options,
  lib,
  inputs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.hardware.disk.longhorn;

  defaultBtrfsOpts = [
    "defaults"
    "compress=zstd:1"
    "ssd"
    "discard=async"
    "noatime"
    "nodiratime"
  ];

  # Standard mount options for ext4/xfs for data drives
  defaultDataMountOpts = [
    "defaults"
    "noatime"
    "nodiratime" # nodiratime is often preferred for performance on data drives
  ];

in
{
  imports = [ inputs.disko.nixosModules.default ];

  options.hardware.disk.longhorn = with types; {
    enable = mkBoolOpt false "Whether or not to configure the OS and Longhorn data disks.";

    os_drive = {
      device_id = mkOption {
        type = types.str;
        default = "";
        description = "OS Drive (e.g., 1TB NVMe) /dev/disk/by-id/ name.";
      };
      swap_size = mkOption {
        type = types.int;
        default = 8192; # Default to 8GB swap, adjust as needed
        description = "Size of swap in MiB, 0 disables swap.";
      };
      # Add other OS drive specific options here if needed in the future
    };

    longhorn_drive = {
      device_id = mkOption {
        type = types.str;
        default = "";
        description = "Longhorn Data Drive (e.g., 2TB NVMe) /dev/disk/by-id/ name.";
      };
      encrypt = mkBoolOpt true "Encrypt the Longhorn drive with LUKS.";
      # Keyfile for Longhorn LUKS, assumed to be on the encrypted OS drive.
      # Ensure this file is created and populated securely (e.g., via agenix, sops-nix, or manual setup).
      luksKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null; # e.g., "/persist/secrets/longhorn_luks.key"
        description = "Path to the keyfile for unlocking the Longhorn LUKS drive. Stored on encrypted OS drive.";
      };
      fsType = mkOption {
        type = types.enum [
          "ext4"
          "xfs"
          "btrfs"
        ];
        default = "ext4"; # ext4 or xfs are commonly recommended for Longhorn data
        description = "Filesystem for Longhorn data drive.";
      };
      mountPoint = mkOption {
        type = types.str;
        default = "/var/lib/longhorn"; # Common path for Longhorn data
        description = "Mount point for the Longhorn data drive.";
      };
    };
  };

  config = mkIf cfg.enable {
    disko.devices = {
      disk = {
        # --- OS Drive Configuration (e.g., 1TB NVMe) ---
        osDrive = {
          device = "/dev/disk/by-id/" + cfg.os_drive.device_id;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                label = "BOOT"; # GPT Partition Label
                name = "ESP"; # GPT Partition Name (for some tools)
                size = "1G"; # Increased to 1G for safety with UKIs, etc.
                type = "EF00"; # EFI System Partition
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [
                    "defaults"
                    "umask=0077"
                  ];
                };
              };
              luks_os = {
                label = "LUKS_OS";
                size = "100%"; # This will take the remaining space after ESP
                content = {
                  type = "luks";
                  name = "cryptroot_os"; # /dev/mapper/cryptroot_os
                  extraOpenArgs = [
                    "--allow-discards" # For SSDs
                    "--perf-no_read_workqueue"
                    "--perf-no_write_workqueue"
                  ];
                  settings = {
                    # For automatic unlocking via TPM/FIDO2.
                    # Ensure your system supports this and it's configured.
                    crypttabExtraOpts = [
                      "tpm2-device=auto"
                      "fido2-device=auto"
                      "token-timeout=10" # Timeout for FIDO2 token prompt
                    ];
                  };
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ]; # Pass -f to mkfs.btrfs
                    subvolumes =
                      {
                        "@root" = {
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
                        # For persistent state not managed by NixOS configuration or Home Manager directly
                        "@persist" = {
                          mountpoint = "/persist";
                          mountOptions = defaultBtrfsOpts;
                        };
                        "@log" = {
                          mountpoint = "/var/log";
                          mountOptions = defaultBtrfsOpts;
                        };
                      }
                      // lib.optionalAttrs (cfg.os_drive.swap_size > 0) {
                        "@swap" = {
                          mountpoint = "/swap"; # Will contain the swapfile
                          # Disko handles creating the swapfile on this Btrfs subvolume
                          swap.swapfile = {
                            size = "${toString cfg.os_drive.swap_size}M";
                            # Btrfs swapfiles require specific handling (no compression, No_COW)
                            # Disko's `swap.swapfile` on Btrfs should ideally handle this.
                            # If not, manual `postCreateHook` commands for `chattr +C` on swapfile parent dir
                            # and `fallocate` might be needed, but disko aims to abstract this.
                          };
                        };
                      };
                  };
                };
              };
            };
          };
        };

        # --- Longhorn Data Drive Configuration (e.g., 2TB NVMe) ---
        longhornDrive = {
          device = "/dev/disk/by-id/" + cfg.longhorn_drive.device_id;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              longhorn_data_storage = {
                # label = "LONGHORN_DATA"; # GPT Partition Label
                # size = "100%"; # Take the whole disk
                content =
                  if cfg.longhorn_drive.encrypt then
                    {
                      type = "luks";
                      name = "crypt_longhorn"; # /dev/mapper/crypt_longhorn
                      extraOpenArgs = [ "--allow-discards" ];
                      settings = lib.mkMerge [
                        (lib.optionalAttrs (cfg.longhorn_drive.luksKeyFile != null) {
                          keyFile = cfg.longhorn_drive.luksKeyFile;
                          # If using a keyFile, crypttabExtraOpts might need 'tries=0' or similar
                          # if you don't want password fallback, or specific options for keyfile handling.
                          # For keyFile, `tpm2-device` might not be used for this specific LUKS volume
                          # unless you have a more complex clevis setup.
                          # crypttabExtraOpts = [ "tries=0" "keyfile-timeout=5" ];
                        })
                        # Example for TPM unlock if no keyfile, or as a fallback/alternative
                        (lib.optionalAttrs (cfg.longhorn_drive.luksKeyFile == null) {
                          crypttabExtraOpts = [
                            "tpm2-device=auto"
                            "token-timeout=5"
                          ];
                        })
                      ];
                      content = {
                        type = "filesystem";
                        format = cfg.longhorn_drive.fsType;
                        mountpoint = cfg.longhorn_drive.mountPoint;
                        mountOptions =
                          if cfg.longhorn_drive.fsType == "btrfs" then defaultBtrfsOpts else defaultDataMountOpts;
                      };
                    }
                  else
                    {
                      # Not encrypted
                      type = "filesystem";
                      format = cfg.longhorn_drive.fsType;
                      mountpoint = cfg.longhorn_drive.mountPoint;
                      mountOptions =
                        if cfg.longhorn_drive.fsType == "btrfs" then defaultBtrfsOpts else defaultDataMountOpts;
                    };
              };
            };
          };
        };
      };
    };

    # These ensure that NixOS knows these paths are critical for persisting data across reboots,
    # especially relevant for impermanence setups where / is tmpfs or rolled back.
    # Disko creates these entries in fileSystems, but explicitly setting neededForBoot can be important.
    fileSystems."/persist".neededForBoot = true;
    fileSystems."/var/log".neededForBoot = true; # For persistent logs, crucial for debugging.
    # fileSystems."/home".neededForBoot = true; # If /home is not on a separate partition managed elsewhere
    # and needs to be available early. Disko sets it up.

    # For the Longhorn data mount, it's usually not needed for early boot (initrd stage).
    # Disko will create the fileSystems entry. If you need to override options:
    # fileSystems.${cfg.longhorn_drive.mountPoint}.neededForBoot = false;

    # age.secrets = {
    #   "foo" = {
    #     rekeyFile = lib.${namespace}.relativeToRoot "secrets/foo.age";
    #     owner = "media";
    #     group = "media";
    #   };
    # };
  };
}

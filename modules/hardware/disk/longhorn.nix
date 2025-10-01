# NixOS module for configuring OS drive (encrypted Btrfs) and a dedicated Longhorn data drive.
{ inputs, ... }:

{
  flake.aspects.disk-longhorn.nixos =
    {
      config,
      lib,
      ...
    }:
    with lib;
    let
      defaultBtrfsOpts = [
        "defaults"
        "compress=zstd:1"
        "ssd"
        "discard=async"
        "noatime"
        "nodiratime"
      ];

      defaultDataMountOpts = [
        "defaults"
        "noatime"
        "nodiratime"
      ];

    in
    {
      imports = [ inputs.disko.nixosModules.default ];

      options.hardware.disk.longhorn = with lib.types; {

        os_drive = {
          device_id = mkOption {
            type = types.str;
            default = "";
            description = "OS Drive /dev/disk/by-id/ name (e.g., ata-...). THIS IS REQUIRED.";
          };
          swap_size = mkOption {
            type = types.int;
            default = 8192;
            description = "Size of swap in MiB for the OS drive, 0 disables swap.";
          };
        };

        longhorn_drive = {
          device_id = mkOption {
            type = types.str;
            default = "";
            description = "Longhorn Data Drive /dev/disk/by-id/ name (e.g., nvme-...). THIS IS REQUIRED.";
          };
          encrypt = mkOption {
            type = types.bool;
            default = false;
            description = "Encrypt the Longhorn drive with LUKS.";
          };
          luksKeyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Absolute path to the keyfile for unlocking the Longhorn LUKS drive (e.g., /persist/secrets/longhorn_luks.key).";
          };
          fsType = mkOption {
            type = types.enum [
              "ext4"
              "xfs"
              "btrfs"
            ];
            default = "xfs";
            description = "Filesystem for Longhorn data drive.";
          };
          mountPoint = mkOption {
            type = types.str;
            default = "/var/lib/longhorn";
            description = "Mount point for the Longhorn data drive.";
          };
        };
      };

      config =
        let
          lhCfg = config.hardware.disk.longhorn;
        in
        {
          assertions = [
            {
              assertion = lhCfg.os_drive.device_id != "";
              message = "hardware.disk.longhorn.os_drive.device_id must be set.";
            }
            {
              assertion = lhCfg.longhorn_drive.device_id != "";
              message = "hardware.disk.longhorn.longhorn_drive.device_id must be set.";
            }
            {
              assertion =
                !(
                  lhCfg.longhorn_drive.encrypt
                  && lhCfg.longhorn_drive.luksKeyFile != null
                  && !(
                    builtins.isPath lhCfg.longhorn_drive.luksKeyFile
                    && builtins.pathExists lhCfg.longhorn_drive.luksKeyFile
                  )
                );
              message = ''
                If hardware.disk.longhorn.longhorn_drive.encrypt is true and luksKeyFile is set,
                it must be an existing path. Value: ${toString lhCfg.longhorn_drive.luksKeyFile}
              '';
            }
          ];

          disko.devices = {
            disk = {
              os = lib.mkIf (lhCfg.os_drive.device_id != "") {
                device = "/dev/disk/by-id/" + lhCfg.os_drive.device_id;
                type = "disk";
                content = {
                  type = "gpt";
                  partitions = {
                    ESP = {
                      label = "BOOT";
                      name = "ESP";
                      size = "1G";
                      type = "EF00";
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
                    nixos = {
                      label = "nixos";
                      size = "100%";
                      content = {
                        type = "luks";
                        name = "cryptroot_os";
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
                            "nixos_os"
                            "-f"
                          ];
                          subvolumes = {
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
                            "@persist" = {
                              mountpoint = "/persist";
                              mountOptions = defaultBtrfsOpts;
                            };
                            "@log" = {
                              mountpoint = "/var/log";
                              mountOptions = defaultBtrfsOpts;
                            };
                          }
                          // lib.optionalAttrs (lhCfg.os_drive.swap_size > 0) {
                            "@swap" = {
                              mountpoint = "/swap";
                              swap.swapfile = {
                                size = "${toString lhCfg.os_drive.swap_size}M";
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                };
              };

              data = lib.mkIf (lhCfg.longhorn_drive.device_id != "") {
                device = "/dev/disk/by-id/" + lhCfg.longhorn_drive.device_id;
                type = "disk";
                content = {
                  type = "gpt";
                  partitions = {
                    longhorn = {
                      label = "longhorn";
                      size = "100%";
                      content =
                        if lhCfg.longhorn_drive.encrypt then
                          {
                            type = "luks";
                            name = "crypt_longhorn";
                            extraOpenArgs = [ "--allow-discards" ];
                            settings = lib.mkMerge [
                              (lib.optionalAttrs (lhCfg.longhorn_drive.luksKeyFile != null) {
                                keyFile = lhCfg.longhorn_drive.luksKeyFile;
                              })
                              (lib.optionalAttrs (lhCfg.longhorn_drive.luksKeyFile == null) {
                                crypttabExtraOpts = [
                                  "tpm2-device=auto"
                                  "fido2-device=auto"
                                  "token-timeout=5"
                                ];
                              })
                            ];
                            content = {
                              type = "filesystem";
                              format = lhCfg.longhorn_drive.fsType;
                              mountpoint = lhCfg.longhorn_drive.mountPoint;
                              mountOptions =
                                if lhCfg.longhorn_drive.fsType == "btrfs" then defaultBtrfsOpts else defaultDataMountOpts;
                            };
                          }
                        else
                          {
                            # Not encrypted
                            type = "filesystem";
                            format = lhCfg.longhorn_drive.fsType;
                            mountpoint = lhCfg.longhorn_drive.mountPoint;
                            mountOptions =
                              if lhCfg.longhorn_drive.fsType == "btrfs" then defaultBtrfsOpts else defaultDataMountOpts;
                          };
                    };
                  };
                };
              };
            };
          };

          fileSystems."/persist".neededForBoot = true;
          fileSystems."/var/log".neededForBoot = true;
        };
    };
}

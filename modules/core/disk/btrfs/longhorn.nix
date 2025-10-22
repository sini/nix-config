# NixOS module for configuring OS drive (encrypted Btrfs) and a dedicated Longhorn data drive.
{ inputs, ... }:

{
  flake.features.disk-longhorn.nixos =
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
        };
    };
}

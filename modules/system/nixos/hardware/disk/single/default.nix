# Luks2 encrypted disk with btrfs subvolumes, depends on facter report
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
  cfg = config.hardware.disk.single;

  disk-device =
    if cfg.device_id != "" then
      "/dev/disk/by-id/" + cfg.device_id
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
        abort ("Multiple disks found: " + builtins.toString disk-labels);
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

  options.hardware.disk.single = with types; {
    enable = mkBoolOpt false "Whether or not to configure disk.";
    device_id = mkOption {
      type = types.str;
      default = "";
      description = "(Optional) Disk device id.";
    };
    swap_size = mkOption {
      type = types.int;
      default = 0;
      description = "Size of swap in MiB, 0 disables swap.";
    };
  };
  config = mkIf cfg.enable {
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
                  mountOptions = [
                    "defaults"
                  ];
                };
              };
              luks = {
                size = "100%";
                label = "luks";
                content = {
                  type = "luks";
                  name = "cryptroot";
                  extraOpenArgs = [
                    "--allow-discards"
                    "--perf-no_read_workqueue"
                    "--perf-no_write_workqueue"
                  ];
                  # https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html
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
                    subvolumes =
                      {
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
                      }
                      // lib.optionalAttrs (cfg.swap_size > 0) {
                        "@swap" = {
                          mountpoint = "/swap";
                          swap.swapfile.size = "${builtins.toString cfg.swap_size}M";
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

    fileSystems."/persist".neededForBoot = true;
    fileSystems."/var/log".neededForBoot = true;

  };
}

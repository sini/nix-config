# Luks2 encrypted disk with btrfs subvolumes, depends on facter report
{ inputs, ... }:
{
  flake.features.disk-single.nixos =
    {
      config,
      lib,
      ...
    }:
    with lib;

    let
      disk-device =
        if config.hardware.disk.single.device_id != "" then
          "/dev/disk/by-id/" + config.hardware.disk.single.device_id
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
              "Multiple disks found. Please specify hardware.disk.single.device_id. Found: "
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

      options.hardware.disk.single = with lib.types; {
        device_id = mkOption {
          type = types.str;
          default = "";
          description = ''
            (Optional) Disk device id (e.g., "ata-...").
            If not set, the module attempts to find a single non-USB disk.
            If multiple disks are found or none are found, evaluation will abort
            and this option must be set manually.
          '';
        };
        swap_size = mkOption {
          type = types.int;
          default = 0; # Default to 0 MiB, disabling swap unless specified
          description = "Size of swap in MiB, 0 disables swap.";
        };
      };

      # config = mkIf cfg.enable { # Removed mkIf condition
      config = {
        disko.devices = {
          disk = {
            main = {
              device = disk-device; # Uses the logic defined in the let block
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
                        // lib.optionalAttrs (config.hardware.disk.single.swap_size > 0) {
                          "@swap" = {
                            mountpoint = "/swap";
                            swap.swapfile.size = "${toString config.hardware.disk.single.swap_size}M";
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
        fileSystems."/home".neededForBoot = true;
        fileSystems."/var/log".neededForBoot = true;
      };
    };
}

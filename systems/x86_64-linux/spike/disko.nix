# Luks2 encrypted disk with btrfs subvolumes, depends on facter report
{
  inputs,
  ...
}:
{
  # This is manually composed and somewhat fragile.
  imports = [ inputs.disko.nixosModules.default ];
  config = {
    disko.devices = {
      disk = {
        main = {
          device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                label = "boot";
                name = "ESP";
                start = "4cyl";
                end = "4019cyl";
                type = "EF00";
                # flags: boot, esp, no_automount
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [
                    "defaults"
                  ];
                };
              };
              winHead = {
                name = "WinHead";
                start = "4019cyl";
                end = "4083cyl";
                # flags: msftres, no_automount
                content = null; # Placeholder for Windows boot partition
              };
              windows = {
                name = "Windows";
                start = "4083cyl";
                end = "4044133cyl";
                type = "0700";
                content = {
                  type = "filesystem";
                  format = "ntfs";
                  mountpoint = "/mnt/windows";
                  mountOptions = [
                    "defaults"
                    "uid=1000"
                    "gid=1000"
                    "umask=022"
                  ];
                };
              };
              windowsRecovery = {
                name = "Windows";
                start = "4044133cyl";
                end = "4046719cyl";
                type = "0700";
                # flags: hidden, diag, no_automount
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
                      let
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
                        "@swap" = {
                          mountpoint = "/swap";
                          swap.swapfile.size = "64G";
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

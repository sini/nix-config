{
  flake.features.btrfs.nixos =
    { pkgs, ... }:
    {
      boot.supportedFilesystems.btrfs = true;

      services.btrfs.autoScrub = {
        enable = true;
        fileSystems = [ "/" ];
      };

      environment.systemPackages = with pkgs; [
        (writeShellApplication {
          name = "btrfs-diff";
          runtimeInputs = [
            coreutils
            gnused
            btrfs-progs
          ];
          text = ''
            # shellcheck disable=SC2148
            OLD_TRANSID=$(sudo btrfs subvolume find-new /mnt/root-blank 9999999)
            OLD_TRANSID=''${OLD_TRANSID#transid marker was }

            # shellcheck disable=SC2312
            sudo btrfs subvolume find-new "/mnt/root" "''${OLD_TRANSID}" |
              sed '$d' |
              cut -f17- -d' ' |
              sort |
              uniq |
              while read -r path; do
                path="/''${path}"
                if [[ -L "''${path}" ]]; then
                  : # The path is a symbolic link, so is probably handled by NixOS already
                elif [[ -d "''${path}" ]]; then
                  : # The path is a directory, ignore
                else
                  echo "''${path}"
                fi
              done
          '';
        })
        (writeShellApplication {
          name = "btrfs-root-diff";
          runtimeInputs = [
            coreutils
            gnused
            btrfs-progs
          ];
          text = ''
            sudo mkdir -p /mnt
            sudo mount -o subvol=/ /dev/mapper/cryptroot /mnt
            btrfs-diff
            sudo umount /mnt
          '';
        })
        (writeShellApplication {
          name = "btrfs-home-diff";
          runtimeInputs = [
            coreutils
            gnused
            btrfs-progs
          ];
          text = ''
            sudo mkdir -p /mnt
            sudo mount -o subvol=/ /dev/mapper/cryptroot /mnt
            btrfs-diff
            sudo umount /mnt
          '';
        })
      ];
    };
}

_: {
  den.aspects.disk.btrfs = {
    nixos =
      { pkgs, ... }:
      {
        boot.supportedFilesystems.btrfs = true;

        services.btrfs.autoScrub = {
          enable = true;
          fileSystems = [ "/" ];
        };

        environment.systemPackages = [
          (pkgs.writeShellApplication {
            name = "btrfs-diff";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gnused
              pkgs.btrfs-progs
            ];
            text = ''
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
                    :
                  elif [[ -d "''${path}" ]]; then
                    :
                  else
                    echo "''${path}"
                  fi
                done
            '';
          })
          (pkgs.writeShellApplication {
            name = "btrfs-root-diff";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gnused
              pkgs.btrfs-progs
            ];
            text = ''
              sudo mkdir -p /mnt
              sudo mount -o subvol=/ /dev/mapper/cryptroot /mnt
              btrfs-diff
              sudo umount /mnt
            '';
          })
          (pkgs.writeShellApplication {
            name = "btrfs-home-diff";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gnused
              pkgs.btrfs-progs
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
  };
}

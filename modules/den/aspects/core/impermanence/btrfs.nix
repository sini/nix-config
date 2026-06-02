# BTRFS impermanence rollback (legacy -- use ZFS for new systems).
# Initrd services that restore root/home from blank btrfs snapshots.
{ den, lib, ... }:
{
  den.aspects.core.impermanence.btrfs = {
    nixos =
      { host, ... }:
      {
        config = lib.mkIf (host.hasAspect den.aspects.disk.btrfs) {
          boot.initrd.systemd.services = {
            rollback-btrfs-root = lib.mkIf (host.settings.core.impermanence.wipeRootOnBoot or false) {
              description = "Rollback BTRFS root subvolume to a pristine state";
              wantedBy = [ "initrd.target" ];
              after = [ "systemd-cryptsetup@cryptroot.service" ];
              before = [ "sysroot.mount" ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = ''
                mkdir -p /mnt

                mount -o subvol=/ /dev/mapper/cryptroot /mnt
                btrfs subvolume list -o /mnt/root

                # Delete nested subvolumes first (systemd containers, etc.)
                btrfs subvolume list -o /mnt/root |
                cut -f9 -d' ' |
                while read subvolume; do
                  echo "deleting /$subvolume subvolume..."
                  btrfs subvolume delete "/mnt/$subvolume"
                done &&
                echo "deleting /root subvolume..." &&
                btrfs subvolume delete /mnt/root

                echo "restoring blank /root subvolume..."
                btrfs subvolume snapshot /mnt/root-blank /mnt/root

                umount /mnt
              '';
            };

            rollback-btrfs-home = lib.mkIf (host.settings.core.impermanence.wipeHomeOnBoot or false) {
              description = "Rollback BTRFS home subvolume to a pristine state";
              wantedBy = [ "initrd.target" ];
              after = [ "systemd-cryptsetup@cryptroot.service" ];
              before = [ "home.mount" ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = ''
                mkdir -p /mnt
                mount -o subvol=/ /dev/mapper/cryptroot /mnt

                btrfs subvolume list -o /mnt/home |
                cut -f9 -d' ' |
                while read subvolume; do
                  echo "deleting /$subvolume subvolume..."
                  btrfs subvolume delete "/mnt/$subvolume"
                done &&
                echo "deleting /home subvolume..." &&
                btrfs subvolume delete /mnt/home

                echo "restoring blank /home subvolume..."
                btrfs subvolume snapshot /mnt/home-blank /mnt/home

                umount /mnt
              '';
            };
          };
        };
      };
  };
}

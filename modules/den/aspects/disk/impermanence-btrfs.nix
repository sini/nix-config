# BTRFS impermanence rollback services — initrd subvolume restore
{ den, ... }:
{
  den.aspects.impermanence-btrfs = den.lib.perHost (
    { host }:
    let
      impCfg = host.impermanence or { };
      wipeRootOnBoot = impCfg.wipeRootOnBoot or true;
      wipeHomeOnBoot = impCfg.wipeHomeOnBoot or false;
    in
    {
      nixos =
        { lib, ... }:
        {
          boot.initrd.systemd.services = {
            rollback-btrfs-root = lib.mkIf wipeRootOnBoot {
              description = "Rollback BTRFS root subvolume to a pristine state";
              wantedBy = [ "initrd.target" ];
              after = [ "systemd-cryptsetup@cryptroot.service" ];
              before = [ "sysroot.mount" ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = ''
                mkdir -p /mnt

                # Mount BTRFS root volume to access subvolumes
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

                # Restore from blank snapshot
                echo "restoring blank /root subvolume..."
                btrfs subvolume snapshot /mnt/root-blank /mnt/root

                umount /mnt
              '';
            };

            rollback-btrfs-home = lib.mkIf wipeHomeOnBoot {
              description = "Rollback BTRFS home subvolume to a pristine state";
              wantedBy = [ "initrd.target" ];
              after = [ "systemd-cryptsetup@cryptroot.service" ];
              before = [ "home.mount" ];
              unitConfig.DefaultDependencies = "no";
              serviceConfig.Type = "oneshot";
              script = ''
                mkdir -p /mnt
                mount -o subvol=/ /dev/mapper/cryptroot /mnt

                # Delete nested subvolumes first
                btrfs subvolume list -o /mnt/home |
                cut -f9 -d' ' |
                while read subvolume; do
                  echo "deleting /$subvolume subvolume..."
                  btrfs subvolume delete "/mnt/$subvolume"
                done &&
                echo "deleting /home subvolume..." &&
                btrfs subvolume delete /mnt/home

                # Restore from blank snapshot
                echo "restoring blank /home subvolume..."
                btrfs subvolume snapshot /mnt/home-blank /mnt/home

                umount /mnt
              '';
            };
          };
        };
    }
  );
}

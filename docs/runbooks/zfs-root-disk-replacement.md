# Runbook: Replace a single-disk ZFS root drive

**Hosts:** any host on `disk.zfs-disk-single` with `core.boot.network-initrd`
(clevis-unlocked, encrypted `zroot`) · **Validated:** 2026-10-19, bitstream
(CA6-8D1024 → Samsung 970 EVO 1TB, nix-config#183)

Use this to move a host's whole root pool onto a new drive while the old one
still reads, ending with a physical swap and a boot that needs nobody at the
console. The new drive is attached alongside the old one for the copy (bitstream
used a USB enclosure), then moved into the old drive's slot.

The approach: build a second pool (`znew`) on the new drive, replicate every
dataset into it while the host keeps running, do one short final incremental
copy with services stopped, make the new drive's partitions indistinguishable
from the old one's, and let a one-shot initrd hook import `znew` as `zroot` on
the first boot after the swap.

## Facts you must know before touching anything

- **A pool can only be renamed on import**, and `zroot` is held while the old
  drive runs. Hence the initrd hook in step 6: on the first boot without the old
  drive there is no `zroot`, so it imports the new pool by GUID under that name.
  Every later boot finds `zroot` and the hook does nothing.
- **Use the same passphrase for `znew` as for `zroot`.** The clevis secret
  unlocks the pool at boot. A different passphrase means typing it at the
  console on the first boot.
- **Send per dataset, without `-p` or `-R`.** A plain send received under an
  encrypted `znew` re-encrypts under `znew` as the encryption root. `-p`/`-R`
  carries the source's encryption properties and breaks that. Copy each
  dataset's _local_ properties across with `zfs set` instead, then check them
  (step 4).
- **Keep every snapshot**, `@empty` especially: `wipeRootOnBoot` rolls
  `zroot/local/root` back to `@empty` at every boot. An incremental chain from
  `@empty` (`zfs send -I`) brings all of them across.
- **After step 7 the two drives share partition names and PARTUUIDs.** Never
  boot with both installed after that.
- **USB enclosures may bind to `usb-storage`, not UAS.** bitstream's did, and
  reads off the Samsung ran at 13–40 MB/s. The 132 GB copy took about 1.5 h, and
  a full-content compare of a 43 GB `persist` was still running after 35 min.
- **Bad sectors on the old drive.** Watch `smartctl -A` (Media and Data
  Integrity Errors) and `zpool status -v zroot` during the copy. A read error
  ZFS repairs ("No known data errors") is fine; a permanent error names the file
  to restore before the cutover.

```bash
NEW=/dev/disk/by-id/ata-<model>_<serial>   # the new drive as attached for the copy
OLD=$(findmnt -no SOURCE /boot | xargs lsblk -no PKNAME | sed 's|^|/dev/|')
```

---

## Step 1 — Partition the new drive like the old one

Same layout as disko's: ESP as partition 1, ZFS as partition 2. The names and
PARTUUIDs get fixed in step 7, so the defaults are fine for now.

```bash
lsblk -o NAME,SIZE "$OLD"    # the ESP's size
printf 'label: gpt\nsize=<ESP size>, type=U\ntype=L\n' | sudo sfdisk "$NEW"
```

Don't copy the table with `sfdisk -d | sfdisk`: that also copies the PARTUUIDs
and names, and `/boot`'s by-partlabel mount becomes ambiguous while both drives
are attached. Partition 2 only has to hold the pool's _allocated_ data, so a
smaller drive works too.

## Step 2 — Create `znew`

Match `zroot`'s pool and root-dataset properties (`zpool get all zroot`,
`zfs get -s local all zroot`). bitstream's:

```bash
sudo zpool create -o ashift=12 -o autotrim=on \
  -O acltype=posixacl -O canmount=off -O checksum=blake3 -O compression=zstd \
  -O dnodesize=auto -O encryption=aes-256-gcm -O keyformat=passphrase \
  -O keylocation=prompt -O mountpoint=none -O normalization=none -O utf8only=off \
  -O relatime=on -O xattr=sa -O com.sun:auto-snapshot=false \
  znew "$NEW-part2"
sudo zfs create -o mountpoint=none -o canmount=off -o reservation=10G \
  -o com.sun:auto-snapshot=false znew/reserved
sudo zpool get -H guid znew   # needed for step 6
```

## Step 3 — First copy (`@mig1`), host still running

```bash
sudo zfs snapshot -r zroot/local@mig1
for ds in $(sudo zfs list -H -o name -r zroot/local); do
  n="znew/${ds#zroot/}"
  sudo zfs send "$ds@empty" | sudo zfs recv -u "$n"
  sudo zfs send -I "$ds@empty" "$ds@mig1" | sudo zfs recv -u "$n"
  sudo zfs get -H -s local -o property,value all "$ds" \
    | grep -vE '^(keylocation|keyformat|encryption|pbkdf2)' \
    | while read -r p v; do sudo zfs set "$p=$v" "$n"; done
done
```

Datasets with no `@empty` (the parents) take a plain `zfs send "$ds@mig1"`.

## Step 4 — Verify `@mig1`

```bash
# same snapshots on both sides
diff <(sudo zfs list -H -t snapshot -o name -r zroot/local | sed 's/^zroot//' | sort) \
     <(sudo zfs list -H -t snapshot -o name -r znew/local  | sed 's/^znew//'  | sort)

# same local properties, and every dataset encrypted under znew
for d in $(sudo zfs list -H -o name -r zroot/local); do
  n="znew/${d#zroot/}"
  diff <(sudo zfs get -H -s local -o property,value all "$d" | grep -vE 'keylocation|keyformat|encryption|pbkdf2' | sort) \
       <(sudo zfs get -H -s local -o property,value all "$n" | sort) >/dev/null || echo "PROPS DIFFER: $d"
  [[ "$(sudo zfs get -H -o value encryptionroot "$n")" == znew ]] || echo "ENCROOT: $n"
done

# file-level compare of what can't be rebuilt, mounted read-only
for d in root persist home; do
  sudo mkdir -p /mnt/v-a/$d /mnt/v-b/$d
  sudo mount -t zfs -o ro zroot/local/$d@mig1 /mnt/v-a/$d
  sudo mount -t zfs -o ro znew/local/$d@mig1  /mnt/v-b/$d
  echo "$d: $(sudo rsync -ac -n -i --delete -HAX /mnt/v-a/$d/ /mnt/v-b/$d/ | wc -l) diffs"
  sudo umount /mnt/v-a/$d /mnt/v-b/$d
done

sudo zpool scrub znew
```

`zfs recv` checksums the stream, so a corrupted transfer fails loudly in step 3.
The `rsync -c` pass is a second, independent check. Spend it on the datasets
that can't be rebuilt: on bitstream `nix`, `cache` and the container stores can
all be reconstructed, and a bad store path shows up later in
`nix-store --verify --check-contents` and is fixed by `--repair`.

## Step 5 — Deploy the cutover hook

Add to the host's `den.aspects.<host>`, with `znew`'s GUID from step 2, and
deploy. Then confirm the GUID is in the initrd that will boot: it's
cpio-prefixed, so decompress from the first zstd frame.

```nix
# TODO: remove once the new disk has booted as zroot.
# The new disk carries pool znew, which can only be renamed on import, and zroot
# is held while the old disk runs. With no zroot present, import that pool (by
# GUID) as zroot; the stock script then sees it imported and runs the clevis
# unlock as usual. mkAfter keeps this behind network-initrd's `load-key -a`,
# which fails on a prompt-keyed pool imported before it. Any zroot on disk,
# including this one after the rename, disarms it.
nixos =
  { config, lib, ... }:
  let
    guid = "<znew guid>";
    zpool = "${config.boot.zfs.package}/sbin/zpool";
  in
  {
    boot.initrd.systemd.services.zfs-import-zroot.preStart = lib.mkAfter ''
      if ! ${zpool} list zroot >/dev/null 2>&1; then
        found=
        for _ in $(seq 1 30); do
          found="$(${zpool} import -d /dev/disk/by-id/ 2>/dev/null)" || true
          case "$found" in *"pool: zroot"* | *"id: ${guid}"*) break ;; esac
          sleep 1
        done
        case "$found" in
          *"pool: zroot"*) ;;
          *"id: ${guid}"*) ${zpool} import -d /dev/disk/by-id/ -N $ZFS_FORCE ${guid} zroot || true ;;
        esac
      fi
    '';
  };
```

```bash
f=$(readlink -f /run/current-system/initrd)
off=$(grep -obUaP '\x28\xb5\x2f\xfd' "$f" | head -1 | cut -d: -f1)
tail -c +$((off+1)) "$f" | zstdcat | grep -a -c '<znew guid>'   # non-zero
```

This was bitstream's commit `43495b09`. The deploy must come **before** step 6,
so the generation it creates is in the final copy and on the copied ESP.

## Step 6 — Final copy (`@mig2`), services stopped

Stop everything that writes, except sshd, networking and your own session.
Anything written after the `@mig2` snapshot stays on the old drive.

```bash
sudo systemctl stop <services> nix-daemon.socket nix-daemon
sync
sudo zfs snapshot -r zroot/local@mig2
for ds in $(sudo zfs list -H -o name -r zroot/local); do
  sudo zfs send -I "$ds@mig1" "$ds@mig2" | sudo zfs recv -u -F "znew/${ds#zroot/}"
done
# then re-run the snapshot diff from step 4
```

## Step 7 — ESP copy, export, make the partitions match

The firmware's NVRAM boot entry points at the old ESP's PARTUUID, and `/boot`
mounts by partition label. Giving the new drive the same of both makes it boot
without touching NVRAM.

```bash
lsblk -o NAME,PARTUUID,UUID "$OLD"   # copy the three values below from this
ESP_UUID=XXXX-XXXX                   # partition 1's UUID (FAT serial)
PART1=<partition 1 PARTUUID>
PART2=<partition 2 PARTUUID>

sudo mkfs.vfat -F 32 -i "${ESP_UUID//-/}" "$NEW-part1"   # same FAT serial
sudo mkdir -p /mnt/newesp
sudo mount "$NEW-part1" /mnt/newesp
sudo rsync -rt --delete /boot/ /mnt/newesp/ && sudo diff -r /boot /mnt/newesp
sudo umount /mnt/newesp

sudo zpool export znew

sudo sfdisk --part-label "$NEW" 1 disk-disk0-ESP
sudo sfdisk --part-label "$NEW" 2 disk-disk0-root
sudo sfdisk --part-uuid  "$NEW" 1 "$PART1"
sudo sfdisk --part-uuid  "$NEW" 2 "$PART2"
lsblk -o NAME,PARTLABEL,PARTUUID,UUID "$NEW"   # must match $OLD's, pool UUID aside
```

## Step 8 — Shut down and swap

`sudo poweroff`, remove the old drive, put the new one in its slot. On boot the
hook imports `znew` as `zroot`, clevis unlocks it, and `zfs-disk-single` rolls
root back as usual. `expandOnBoot` grows the pool if the new partition is
larger.

## Step 9 — After the first good boot

```bash
sudo zpool status zroot                   # ONLINE, on the new drive
systemctl --failed
sudo zpool scrub zroot                    # the znew scrub stops at export
```

Then in nix-config:

- remove the step-5 hook;
- set `settings.disk.zfs-disk-single.device_id` to the new drive's
  `/dev/disk/by-id/nvme-…` name (it was attached as `ata-…` for the copy);
- replace the drive's entry in `hosts/<host>/facter.json`, `hardware.disk[0]`,
  with the one from a fresh `nixos-facter` report. Splice in only that entry: a
  whole fresh report renumbers thousands of unrelated lines.

The `@mig1`/`@mig2` snapshots can be destroyed once you trust the new drive.
Keep the old drive untouched until then.

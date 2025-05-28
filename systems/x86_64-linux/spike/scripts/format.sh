#! /nix/store/41pi0jiyvlhxgpfhxzvb44w1skc8yp4z-bash-interactive-5.2p37/bin/bash
export PATH=/nix/store/2yi7k5ay6xj73rbfqf170gms922rjm2d-jq-1.7.1-bin/bin:/nix/store/gl9if0kjfj2v3h1hr1nsyk4my7xd6wgi-gptfdisk-1.0.10/bin:/nix/store/q69hlng7afnhxdfcsjk4f43gkc3amwf6-systemd-minimal-257.5/bin:/nix/store/wzqvvdf0xhfvcgn6c3y7k6mr5k9l246w-parted-3.6/bin:/nix/store/583p5x4ywdkkfz4s94ddyixz7v77msya-util-linux-2.41-bin/bin:/nix/store/2wni3gbcf6fqwlfb2h9sv7jvqlpf1ylq-gnugrep-3.11/bin:/nix/store/m4j58msw7fpmgrifg76jyy1wx0jm94bc-dosfstools-4.2/bin:/nix/store/nx2v1yfmhx27dm1azckmxvqk8i8da9w8-cryptsetup-2.7.5-bin/bin:/nix/store/k9xpazdwkkcklbvcsjmdnh89h4l1b7sv-btrfs-progs-6.14/bin:/nix/store/9rf6b6s2cs8r62srk00arcydf8xd59jy-coreutils-full-9.7/bin:/nix/store/41pi0jiyvlhxgpfhxzvb44w1skc8yp4z-bash-interactive-5.2p37/bin:$PATH
set -efux

disko_devices_dir=$(mktemp -d)
trap 'rm -rf "$disko_devices_dir"' EXIT
mkdir -p "$disko_devices_dir"

( # disk main /dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E   #
    destroy=1
    device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
    imageName=main
    imageSize=2G
    name=main
    type=disk

    ( # gpt  /dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E   #
        device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
        efiGptPartitionFirst=1
        type=gpt

        ( # luks cryptroot /dev/disk/by-partlabel/luks   #
            declare -a additionalKeyFiles=()
            askPassword=1
            device=/dev/disk/by-partlabel/luks
            declare -a extraFormatArgs=()
            declare -a extraOpenArgs=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue)
            initrdUnlock=1
            keyFile=''
            name=cryptroot
            passwordFile=''
            declare -A settings=([crypttabExtraOpts]='tpm2-device=auto fido2-device=auto token-timeout=10')
            type=luks

            if ! blkid "/dev/disk/by-partlabel/luks" >/dev/null || ! cryptsetup isLuks "/dev/disk/by-partlabel/luks"; then
                promptSecret() {
                    prompt=$1
                    var=$2

                    echo -n "$prompt"
                    IFS= read -r -s "$var"
                    echo
                }

                askPassword() {
                    if [ -z ${IN_DISKO_TEST+x} ]; then
                        set +x
                        promptSecret "Enter password for /dev/disk/by-partlabel/luks: " password
                        promptSecret "Enter password for /dev/disk/by-partlabel/luks again to be safe: " password_check
                        export password
                        [ "$password" = "$password_check" ]
                        set -x
                    else
                        export password=disko
                    fi
                }
                until askPassword; do
                    echo "Passwords did not match, please try again."
                done

                cryptsetup -q luksFormat "/dev/disk/by-partlabel/luks" --key-file <(
                    set +x
                    echo -n "$password"
                    set -x
                )

            fi

            if ! cryptsetup status "cryptroot" >/dev/null; then
                cryptsetup open "/dev/disk/by-partlabel/luks" "cryptroot" \
                    \
                    --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue \
                    --key-file <(
                        set +x
                        echo -n "$password"
                        set -x
                    ) \
                    \
                    --persistent
            fi

            ( # btrfs  /dev/mapper/cryptroot   #
                device=/dev/mapper/cryptroot
                declare -a extraArgs=(-L nixos -f)
                declare -a mountOptions=(defaults)
                mountpoint=''
                type=btrfs

                # create the filesystem only if the device seems empty
                if ! (blkid "/dev/mapper/cryptroot" -o export | grep -q '^TYPE='); then
                    mkfs.btrfs "/dev/mapper/cryptroot" -L nixos -f
                fi
                if (blkid "/dev/mapper/cryptroot" -o export | grep -q '^TYPE=btrfs$'); then

                    (
                        MNTPOINT=$(mktemp -d)
                        mount "/dev/mapper/cryptroot" "$MNTPOINT" -o subvol=/
                        trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                        SUBVOL_ABS_PATH="$MNTPOINT/@home"
                        mkdir -p "$(dirname "$SUBVOL_ABS_PATH")"
                        if ! btrfs subvolume show "$SUBVOL_ABS_PATH" >/dev/null 2>&1; then
                            btrfs subvolume create "$SUBVOL_ABS_PATH"
                        fi

                    )
                    (
                        MNTPOINT=$(mktemp -d)
                        mount "/dev/mapper/cryptroot" "$MNTPOINT" -o subvol=/
                        trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                        SUBVOL_ABS_PATH="$MNTPOINT/@log"
                        mkdir -p "$(dirname "$SUBVOL_ABS_PATH")"
                        if ! btrfs subvolume show "$SUBVOL_ABS_PATH" >/dev/null 2>&1; then
                            btrfs subvolume create "$SUBVOL_ABS_PATH"
                        fi

                    )
                    (
                        MNTPOINT=$(mktemp -d)
                        mount "/dev/mapper/cryptroot" "$MNTPOINT" -o subvol=/
                        trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                        SUBVOL_ABS_PATH="$MNTPOINT/@nix"
                        mkdir -p "$(dirname "$SUBVOL_ABS_PATH")"
                        if ! btrfs subvolume show "$SUBVOL_ABS_PATH" >/dev/null 2>&1; then
                            btrfs subvolume create "$SUBVOL_ABS_PATH"
                        fi

                    )
                    (
                        MNTPOINT=$(mktemp -d)
                        mount "/dev/mapper/cryptroot" "$MNTPOINT" -o subvol=/
                        trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                        SUBVOL_ABS_PATH="$MNTPOINT/@persist"
                        mkdir -p "$(dirname "$SUBVOL_ABS_PATH")"
                        if ! btrfs subvolume show "$SUBVOL_ABS_PATH" >/dev/null 2>&1; then
                            btrfs subvolume create "$SUBVOL_ABS_PATH"
                        fi

                    )
                    (
                        MNTPOINT=$(mktemp -d)
                        mount "/dev/mapper/cryptroot" "$MNTPOINT" -o subvol=/
                        trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                        SUBVOL_ABS_PATH="$MNTPOINT/@root"
                        mkdir -p "$(dirname "$SUBVOL_ABS_PATH")"
                        if ! btrfs subvolume show "$SUBVOL_ABS_PATH" >/dev/null 2>&1; then
                            btrfs subvolume create "$SUBVOL_ABS_PATH"
                        fi

                    )
                    (
                        MNTPOINT=$(mktemp -d)
                        mount "/dev/mapper/cryptroot" "$MNTPOINT" -o subvol=/
                        trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                        SUBVOL_ABS_PATH="$MNTPOINT/@swap"
                        mkdir -p "$(dirname "$SUBVOL_ABS_PATH")"
                        if ! btrfs subvolume show "$SUBVOL_ABS_PATH" >/dev/null 2>&1; then
                            btrfs subvolume create "$SUBVOL_ABS_PATH"
                        fi
                        if ! test -e "$SUBVOL_ABS_PATH/swapfile"; then
                            btrfs filesystem mkswapfile --size 64G "$SUBVOL_ABS_PATH/swapfile"
                        fi

                    )

                fi

            )

        )

    )

)

set -efux
# first create the necessary devices
(
    destroy=1
    device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
    imageName=main
    imageSize=2G
    name=main
    type=disk

    (
        device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
        efiGptPartitionFirst=1
        type=gpt

        (
            declare -a additionalKeyFiles=()
            askPassword=1
            device=/dev/disk/by-partlabel/luks
            declare -a extraFormatArgs=()
            declare -a extraOpenArgs=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue)
            initrdUnlock=1
            keyFile=''
            name=cryptroot
            passwordFile=''
            declare -A settings=([crypttabExtraOpts]='tpm2-device=auto fido2-device=auto token-timeout=10')
            type=luks

            if ! cryptsetup status "cryptroot" >/dev/null 2>/dev/null; then
                if [ -z ${IN_DISKO_TEST+x} ]; then
                    set +x
                    echo "Enter password for /dev/disk/by-partlabel/luks"
                    IFS= read -r -s password
                    export password
                    set -x
                else
                    export password=disko
                fi

                cryptsetup open "/dev/disk/by-partlabel/luks" "cryptroot" \
                    \
                    --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue \
                    --key-file <(
                        set +x
                        echo -n "$password"
                        set -x
                    )

            fi

        )

    )

)

# and then mount the filesystems in alphabetical order
(
    destroy=1
    device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
    imageName=main
    imageSize=2G
    name=main
    type=disk

    (
        device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
        efiGptPartitionFirst=1
        type=gpt

        (
            declare -a additionalKeyFiles=()
            askPassword=1
            device=/dev/disk/by-partlabel/luks
            declare -a extraFormatArgs=()
            declare -a extraOpenArgs=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue)
            initrdUnlock=1
            keyFile=''
            name=cryptroot
            passwordFile=''
            declare -A settings=([crypttabExtraOpts]='tpm2-device=auto fido2-device=auto token-timeout=10')
            type=luks

            (
                device=/dev/mapper/cryptroot
                declare -a extraArgs=(-L nixos -f)
                declare -a mountOptions=(defaults)
                mountpoint=''
                type=btrfs

                if ! findmnt "/dev/mapper/cryptroot" "/mnt/" >/dev/null 2>&1; then
                    mount "/dev/mapper/cryptroot" "/mnt/" \
                        -o defaults -o compress=zstd:1 -o ssd -o discard=async -o noatime -o nodiratime -o subvol=@root \
                        -o X-mount.mkdir
                fi

            )

        )

    )

)
(
    destroy=1
    device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
    imageName=main
    imageSize=2G
    name=main
    type=disk

    (
        device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
        efiGptPartitionFirst=1
        type=gpt

        (
            device=/dev/disk/by-partlabel/boot
            declare -a extraArgs=()
            format=vfat
            declare -a mountOptions=(defaults)
            mountpoint=/boot
            type=filesystem

            if ! findmnt "/dev/disk/by-partlabel/boot" "/mnt/boot" >/dev/null 2>&1; then
                mount "/dev/disk/by-partlabel/boot" "/mnt/boot" \
                    -t "vfat" \
                    -o defaults \
                    -o X-mount.mkdir
            fi

        )

    )

)
(
    destroy=1
    device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
    imageName=main
    imageSize=2G
    name=main
    type=disk

    (
        device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
        efiGptPartitionFirst=1
        type=gpt

        (
            declare -a additionalKeyFiles=()
            askPassword=1
            device=/dev/disk/by-partlabel/luks
            declare -a extraFormatArgs=()
            declare -a extraOpenArgs=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue)
            initrdUnlock=1
            keyFile=''
            name=cryptroot
            passwordFile=''
            declare -A settings=([crypttabExtraOpts]='tpm2-device=auto fido2-device=auto token-timeout=10')
            type=luks

            (
                device=/dev/mapper/cryptroot
                declare -a extraArgs=(-L nixos -f)
                declare -a mountOptions=(defaults)
                mountpoint=''
                type=btrfs

                if ! findmnt "/dev/mapper/cryptroot" "/mnt/home" >/dev/null 2>&1; then
                    mount "/dev/mapper/cryptroot" "/mnt/home" \
                        -o defaults -o compress=zstd:1 -o ssd -o discard=async -o noatime -o nodiratime -o subvol=@home \
                        -o X-mount.mkdir
                fi

            )

        )

    )

)
(
    destroy=1
    device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
    imageName=main
    imageSize=2G
    name=main
    type=disk

    (
        device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
        efiGptPartitionFirst=1
        type=gpt

        (
            declare -a additionalKeyFiles=()
            askPassword=1
            device=/dev/disk/by-partlabel/luks
            declare -a extraFormatArgs=()
            declare -a extraOpenArgs=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue)
            initrdUnlock=1
            keyFile=''
            name=cryptroot
            passwordFile=''
            declare -A settings=([crypttabExtraOpts]='tpm2-device=auto fido2-device=auto token-timeout=10')
            type=luks

            (
                device=/dev/mapper/cryptroot
                declare -a extraArgs=(-L nixos -f)
                declare -a mountOptions=(defaults)
                mountpoint=''
                type=btrfs

                if ! findmnt "/dev/mapper/cryptroot" "/mnt/nix" >/dev/null 2>&1; then
                    mount "/dev/mapper/cryptroot" "/mnt/nix" \
                        -o defaults -o compress=zstd:1 -o ssd -o discard=async -o noatime -o nodiratime -o subvol=@nix \
                        -o X-mount.mkdir
                fi

            )

        )

    )

)
(
    destroy=1
    device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
    imageName=main
    imageSize=2G
    name=main
    type=disk

    (
        device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
        efiGptPartitionFirst=1
        type=gpt

        (
            declare -a additionalKeyFiles=()
            askPassword=1
            device=/dev/disk/by-partlabel/luks
            declare -a extraFormatArgs=()
            declare -a extraOpenArgs=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue)
            initrdUnlock=1
            keyFile=''
            name=cryptroot
            passwordFile=''
            declare -A settings=([crypttabExtraOpts]='tpm2-device=auto fido2-device=auto token-timeout=10')
            type=luks

            (
                device=/dev/mapper/cryptroot
                declare -a extraArgs=(-L nixos -f)
                declare -a mountOptions=(defaults)
                mountpoint=''
                type=btrfs

                if ! findmnt "/dev/mapper/cryptroot" "/mnt/persist" >/dev/null 2>&1; then
                    mount "/dev/mapper/cryptroot" "/mnt/persist" \
                        -o defaults -o compress=zstd:1 -o ssd -o discard=async -o noatime -o nodiratime -o subvol=@persist \
                        -o X-mount.mkdir
                fi

            )

        )

    )

)
(
    destroy=1
    device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
    imageName=main
    imageSize=2G
    name=main
    type=disk

    (
        device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
        efiGptPartitionFirst=1
        type=gpt

        (
            declare -a additionalKeyFiles=()
            askPassword=1
            device=/dev/disk/by-partlabel/luks
            declare -a extraFormatArgs=()
            declare -a extraOpenArgs=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue)
            initrdUnlock=1
            keyFile=''
            name=cryptroot
            passwordFile=''
            declare -A settings=([crypttabExtraOpts]='tpm2-device=auto fido2-device=auto token-timeout=10')
            type=luks

            (
                device=/dev/mapper/cryptroot
                declare -a extraArgs=(-L nixos -f)
                declare -a mountOptions=(defaults)
                mountpoint=''
                type=btrfs

                if ! findmnt "/dev/mapper/cryptroot" "/mnt/swap" >/dev/null 2>&1; then
                    mount "/dev/mapper/cryptroot" "/mnt/swap" \
                        -o defaults -o subvol=@swap \
                        -o X-mount.mkdir
                fi

            )

        )

    )

)
(
    destroy=1
    device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
    imageName=main
    imageSize=2G
    name=main
    type=disk

    (
        device=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S73WNJ0W310392E
        efiGptPartitionFirst=1
        type=gpt

        (
            declare -a additionalKeyFiles=()
            askPassword=1
            device=/dev/disk/by-partlabel/luks
            declare -a extraFormatArgs=()
            declare -a extraOpenArgs=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue)
            initrdUnlock=1
            keyFile=''
            name=cryptroot
            passwordFile=''
            declare -A settings=([crypttabExtraOpts]='tpm2-device=auto fido2-device=auto token-timeout=10')
            type=luks

            (
                device=/dev/mapper/cryptroot
                declare -a extraArgs=(-L nixos -f)
                declare -a mountOptions=(defaults)
                mountpoint=''
                type=btrfs

                if ! findmnt "/dev/mapper/cryptroot" "/mnt/var/log" >/dev/null 2>&1; then
                    mount "/dev/mapper/cryptroot" "/mnt/var/log" \
                        -o defaults -o compress=zstd:1 -o ssd -o discard=async -o noatime -o nodiratime -o subvol=@log \
                        -o X-mount.mkdir
                fi

            )

        )

    )

)

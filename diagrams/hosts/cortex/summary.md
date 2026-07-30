# Host: cortex

## Overview

- **235** aspects across **1** classes (nixos)
- **294** provider sub-aspects
- **51** policies fired
- **5** entity instances

## Aspects

| Aspect | Classes | Parametric | Instance |
| -------- | --------- | ------------ | ---------- |
| agenix-identity/shuo@blade | nixos | yes (host, secretsConfig, user) | user:shuo |
| agenix-identity/shuo@cortex | nixos | yes (host, secretsConfig, user) | user:shuo |
| agenix-identity/sini@axon-01 | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@axon-02 | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@axon-03 | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@bitstream | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@blade | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@cortex | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@uplink | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/vic@axon-01 | nixos | yes (host, secretsConfig, user) | user:vic |
| agenix-identity/vic@axon-02 | nixos | yes (host, secretsConfig, user) | user:vic |
| agenix-identity/vic@axon-03 | nixos | yes (host, secretsConfig, user) | user:vic |
| agenix-identity/vic@bitstream | nixos | yes (host, secretsConfig, user) | user:vic |
| agenix-identity/vic@blade | nixos | yes (host, secretsConfig, user) | user:vic |
| agenix-identity/vic@cortex | nixos | yes (host, secretsConfig, user) | user:vic |
| agenix-identity/vic@uplink | nixos | yes (host, secretsConfig, user) | user:vic |
| agenix-identity/will@blade | nixos | yes (host, secretsConfig, user) | user:will |
| agenix-identity/will@cortex | nixos | yes (host, secretsConfig, user) | user:will |
| agenix/cortex | nixos | yes (host, secretsConfig) | host:cortex |
| ai/ollama | nixos | no | host:cortex |
| applications/gaming/steam | nixos | no | user:shuo |
| applications/gaming/steam | nixos | no | host:cortex |
| batteries/define-user/shuo@cortex | nixos | yes (host, user) | host:cortex |
| batteries/define-user/sini@cortex | nixos | yes (host, user) | host:cortex |
| batteries/define-user/vic@cortex | nixos | yes (host, user) | host:cortex |
| batteries/define-user/will@cortex | nixos | yes (host, user) | host:cortex |
| batteries/hostname/os | nixos | yes (host) | host:cortex |
| batteries/inputs'/os | nixos | yes (host) | host:cortex |
| batteries/primary-user(sini@axon-01) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@axon-02) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@axon-03) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@bitstream) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@blade) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@cortex) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@patch) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@slab) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@uplink) | nixos | yes (host, user) | user:sini |
| batteries/self'/os | nixos | yes (host) | host:cortex |
| boot/network-initrd | nixos | no | host:cortex |
| core/impermanence | nixos | no | user:vic |
| core/impermanence | nixos | no | user:shuo |
| core/impermanence | nixos | no | user:will |
| core/impermanence | nixos | no | host:cortex |
| core/impermanence/btrfs | nixos | no | user:vic |
| core/impermanence/btrfs | nixos | no | user:shuo |
| core/impermanence/btrfs | nixos | no | user:will |
| core/impermanence/btrfs | nixos | no | host:cortex |
| core/impermanence/persist-collector | nixos | no | user:vic |
| core/impermanence/persist-collector | nixos | no | user:shuo |
| core/impermanence/persist-collector | nixos | no | user:will |
| core/impermanence/persist-collector | nixos | no | host:cortex |
| core/impermanence/zfs | nixos | no | user:vic |
| core/impermanence/zfs | nixos | no | user:shuo |
| core/impermanence/zfs | nixos | no | user:will |
| core/impermanence/zfs | nixos | no | host:cortex |
| core/localization/i18n | nixos | no | user:vic |
| core/localization/i18n | nixos | no | user:shuo |
| core/localization/i18n | nixos | no | user:will |
| core/localization/i18n | nixos | no | host:cortex |
| core/network/hostsfile | nixos | no | user:vic |
| core/network/hostsfile | nixos | no | user:shuo |
| core/network/hostsfile | nixos | no | user:will |
| core/network/hostsfile | nixos | no | host:cortex |
| core/network/networking | nixos | no | user:vic |
| core/network/networking | nixos | no | user:shuo |
| core/network/networking | nixos | no | user:will |
| core/network/networking | nixos | no | host:cortex |
| core/network/syncthing/peer | nixos | no | user:sini |
| core/network/syncthing/peer | nixos | no | user:vic |
| core/network/syncthing/peer | nixos | no | user:shuo |
| core/network/syncthing/peer | nixos | no | user:will |
| core/network/tailscale | nixos | no | user:vic |
| core/network/tailscale | nixos | no | user:shuo |
| core/network/tailscale | nixos | no | user:will |
| core/network/tailscale | nixos | no | host:cortex |
| core/nix | nixos | no | user:vic |
| core/nix | nixos | no | user:shuo |
| core/nix | nixos | no | user:will |
| core/nix | nixos | no | host:cortex |
| core/nix/stateVersion | nixos | no | user:vic |
| core/nix/stateVersion | nixos | no | user:shuo |
| core/nix/stateVersion | nixos | no | user:will |
| core/nix/stateVersion | nixos | no | host:cortex |
| core/perf/disable-docs | nixos | no | user:vic |
| core/perf/disable-docs | nixos | no | user:shuo |
| core/perf/disable-docs | nixos | no | user:will |
| core/perf/disable-docs | nixos | no | host:cortex |
| core/perf/ssd | nixos | no | user:vic |
| core/perf/ssd | nixos | no | user:shuo |
| core/perf/ssd | nixos | no | user:will |
| core/perf/ssd | nixos | no | host:cortex |
| core/perf/zram-swap | nixos | no | user:vic |
| core/perf/zram-swap | nixos | no | user:shuo |
| core/perf/zram-swap | nixos | no | user:will |
| core/perf/zram-swap | nixos | no | host:cortex |
| core/security | nixos | no | user:vic |
| core/security | nixos | no | user:shuo |
| core/security | nixos | no | user:will |
| core/security | nixos | no | host:cortex |
| core/security/openssh | nixos | no | user:vic |
| core/security/openssh | nixos | no | user:shuo |
| core/security/openssh | nixos | no | user:will |
| core/security/openssh | nixos | no | host:cortex |
| core/security/opkssh | nixos | no | user:vic |
| core/security/opkssh | nixos | no | user:shuo |
| core/security/opkssh | nixos | no | user:will |
| core/security/opkssh | nixos | no | host:cortex |
| core/security/sudo | nixos | no | user:vic |
| core/security/sudo | nixos | no | user:shuo |
| core/security/sudo | nixos | no | user:will |
| core/security/sudo | nixos | no | host:cortex |
| core/system/facter | nixos | no | user:vic |
| core/system/facter | nixos | no | user:shuo |
| core/system/facter | nixos | no | user:will |
| core/system/facter | nixos | no | host:cortex |
| core/system/firmware | nixos | no | user:vic |
| core/system/firmware | nixos | no | user:shuo |
| core/system/firmware | nixos | no | user:will |
| core/system/firmware | nixos | no | host:cortex |
| core/system/linux-kernel | nixos | no | user:vic |
| core/system/linux-kernel | nixos | no | user:shuo |
| core/system/linux-kernel | nixos | no | user:will |
| core/system/linux-kernel | nixos | no | host:cortex |
| core/systemd | nixos | no | user:vic |
| core/systemd | nixos | no | user:shuo |
| core/systemd | nixos | no | user:will |
| core/systemd | nixos | no | host:cortex |
| core/systemd/boot | nixos | no | user:vic |
| core/systemd/boot | nixos | no | user:shuo |
| core/systemd/boot | nixos | no | user:will |
| core/systemd/boot | nixos | no | host:cortex |
| core/users | nixos | no | user:vic |
| core/users | nixos | no | user:shuo |
| core/users | nixos | no | user:will |
| core/users | nixos | no | host:cortex |
| core/users/deterministic-uids | nixos | no | user:vic |
| core/users/deterministic-uids | nixos | no | user:shuo |
| core/users/deterministic-uids | nixos | no | user:will |
| core/users/deterministic-uids | nixos | no | host:cortex |
| core/users/home-manager-shared | nixos | no | user:vic |
| core/users/home-manager-shared | nixos | no | user:shuo |
| core/users/home-manager-shared | nixos | no | user:will |
| core/users/home-manager-shared | nixos | no | host:cortex |
| core/users/shell | nixos | no | user:vic |
| core/users/shell | nixos | no | user:shuo |
| core/users/shell | nixos | no | user:will |
| core/users/shell | nixos | no | host:cortex |
| core/utils | nixos | no | user:vic |
| core/utils | nixos | no | user:shuo |
| core/utils | nixos | no | user:will |
| core/utils | nixos | no | host:cortex |
| cortex | nixos | yes (host) | host:cortex |
| cpu/amd | nixos | no | host:cortex |
| desktop/gdm | nixos | no | host:cortex |
| desktop/gnome | nixos | no | host:cortex |
| desktop/uwsm | nixos | no | host:cortex |
| desktop/xdg-portal | nixos | no | host:cortex |
| desktop/xserver | nixos | no | host:cortex |
| desktop/xwayland | nixos | no | host:cortex |
| disk/zfs-diff | nixos | no | host:cortex |
| disk/zfs-disk-single | nixos | no | host:cortex |
| fonts/nerd-fonts | nixos | no | host:cortex |
| fonts/regular | nixos | no | host:cortex |
| gaming/emulation | nixos | no | host:cortex |
| gaming/nix-ld | nixos | no | host:cortex |
| gaming/sunshine | nixos | no | host:cortex |
| gpu/amd | nixos | no | host:cortex |
| gpu/nvidia-vfio | nixos | no | host:cortex |
| hardware/adb | nixos | no | host:cortex |
| hardware/audio | nixos | no | host:cortex |
| hardware/bluetooth | nixos | no | host:cortex |
| hardware/coolercontrol | nixos | no | host:cortex |
| hardware/ddcutil | nixos | no | host:cortex |
| hardware/gamepad | nixos | no | host:cortex |
| hardware/keyboard | nixos | no | host:cortex |
| hardware/performance | nixos | no | host:cortex |
| hardware/vr-amd | nixos | no | host:cortex |
| host/resolve(dev-gui) | nixos | no | host:cortex |
| insecure-predicate/os | nixos | yes (host) | host:cortex |
| media/easyeffects | nixos | no | host:cortex |
| messaging/kdeconnect | nixos | no | host:cortex |
| network/firewall-collector | nixos | no | host:cortex |
| nix/remote-build-server | nixos | no | host:cortex |
| opkssh-authz/shuo@blade | nixos | yes (host, user) | user:shuo |
| opkssh-authz/shuo@cortex | nixos | yes (host, user) | user:shuo |
| opkssh-authz/sini@axon-01 | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@axon-02 | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@axon-03 | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@bitstream | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@blade | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@cortex | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@patch | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@slab | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@uplink | nixos | yes (host, user) | user:sini |
| opkssh-authz/vic@axon-01 | nixos | yes (host, user) | user:vic |
| opkssh-authz/vic@axon-02 | nixos | yes (host, user) | user:vic |
| opkssh-authz/vic@axon-03 | nixos | yes (host, user) | user:vic |
| opkssh-authz/vic@bitstream | nixos | yes (host, user) | user:vic |
| opkssh-authz/vic@blade | nixos | yes (host, user) | user:vic |
| opkssh-authz/vic@cortex | nixos | yes (host, user) | user:vic |
| opkssh-authz/vic@uplink | nixos | yes (host, user) | user:vic |
| opkssh-authz/will@blade | nixos | yes (host, user) | user:will |
| opkssh-authz/will@cortex | nixos | yes (host, user) | user:will |
| provides/unfree(antigravity) | nixos | yes (class, host) | host:cortex |
| provides/unfree(corefonts,vista-fonts) | nixos | yes (class, host) | host:cortex |
| secrets/collector | nixos | no | host:cortex |
| storage/media-data-share | nixos | no | host:cortex |
| style/fonts | nixos | no | host:cortex |
| style/stylix | nixos | no | host:cortex |
| unfree-predicate/os | nixos | yes (host) | host:cortex |
| user-enrich/shuo@blade | nixos | yes (host, user) | user:shuo |
| user-enrich/shuo@cortex | nixos | yes (host, user) | user:shuo |
| user-enrich/sini@axon-01 | nixos | yes (host, user) | user:sini |
| user-enrich/sini@axon-02 | nixos | yes (host, user) | user:sini |
| user-enrich/sini@axon-03 | nixos | yes (host, user) | user:sini |
| user-enrich/sini@bitstream | nixos | yes (host, user) | user:sini |
| user-enrich/sini@blade | nixos | yes (host, user) | user:sini |
| user-enrich/sini@cortex | nixos | yes (host, user) | user:sini |
| user-enrich/sini@patch | nixos | yes (host, user) | user:sini |
| user-enrich/sini@slab | nixos | yes (host, user) | user:sini |
| user-enrich/sini@uplink | nixos | yes (host, user) | user:sini |
| user-enrich/vic@axon-01 | nixos | yes (host, user) | user:vic |
| user-enrich/vic@axon-02 | nixos | yes (host, user) | user:vic |
| user-enrich/vic@axon-03 | nixos | yes (host, user) | user:vic |
| user-enrich/vic@bitstream | nixos | yes (host, user) | user:vic |
| user-enrich/vic@blade | nixos | yes (host, user) | user:vic |
| user-enrich/vic@cortex | nixos | yes (host, user) | user:vic |
| user-enrich/vic@uplink | nixos | yes (host, user) | user:vic |
| user-enrich/will@blade | nixos | yes (host, user) | user:will |
| user-enrich/will@cortex | nixos | yes (host, user) | user:will |
| virtualization/libvirt | nixos | no | host:cortex |
| virtualization/microvm-host | nixos | no | host:cortex |
| virtualization/podman | nixos | no | host:cortex |
| virtualization/windows-vfio | nixos | no | host:cortex |
| zfs-disk-single/root | nixos | no | host:cortex |

## Classes

### nixos (235)

- agenix-identity/shuo@blade
- agenix-identity/shuo@cortex
- agenix-identity/sini@axon-01
- agenix-identity/sini@axon-02
- agenix-identity/sini@axon-03
- agenix-identity/sini@bitstream
- agenix-identity/sini@blade
- agenix-identity/sini@cortex
- agenix-identity/sini@uplink
- agenix-identity/vic@axon-01
- agenix-identity/vic@axon-02
- agenix-identity/vic@axon-03
- agenix-identity/vic@bitstream
- agenix-identity/vic@blade
- agenix-identity/vic@cortex
- agenix-identity/vic@uplink
- agenix-identity/will@blade
- agenix-identity/will@cortex
- agenix/cortex
- ai/ollama
- applications/gaming/steam
- applications/gaming/steam
- batteries/define-user/shuo@cortex
- batteries/define-user/sini@cortex
- batteries/define-user/vic@cortex
- batteries/define-user/will@cortex
- batteries/hostname/os
- batteries/inputs'/os
- batteries/primary-user(sini@axon-01)
- batteries/primary-user(sini@axon-02)
- batteries/primary-user(sini@axon-03)
- batteries/primary-user(sini@bitstream)
- batteries/primary-user(sini@blade)
- batteries/primary-user(sini@cortex)
- batteries/primary-user(sini@patch)
- batteries/primary-user(sini@slab)
- batteries/primary-user(sini@uplink)
- batteries/self'/os
- boot/network-initrd
- core/impermanence
- core/impermanence
- core/impermanence
- core/impermanence
- core/impermanence/btrfs
- core/impermanence/btrfs
- core/impermanence/btrfs
- core/impermanence/btrfs
- core/impermanence/persist-collector
- core/impermanence/persist-collector
- core/impermanence/persist-collector
- core/impermanence/persist-collector
- core/impermanence/zfs
- core/impermanence/zfs
- core/impermanence/zfs
- core/impermanence/zfs
- core/localization/i18n
- core/localization/i18n
- core/localization/i18n
- core/localization/i18n
- core/network/hostsfile
- core/network/hostsfile
- core/network/hostsfile
- core/network/hostsfile
- core/network/networking
- core/network/networking
- core/network/networking
- core/network/networking
- core/network/syncthing/peer
- core/network/syncthing/peer
- core/network/syncthing/peer
- core/network/syncthing/peer
- core/network/tailscale
- core/network/tailscale
- core/network/tailscale
- core/network/tailscale
- core/nix
- core/nix
- core/nix
- core/nix
- core/nix/stateVersion
- core/nix/stateVersion
- core/nix/stateVersion
- core/nix/stateVersion
- core/perf/disable-docs
- core/perf/disable-docs
- core/perf/disable-docs
- core/perf/disable-docs
- core/perf/ssd
- core/perf/ssd
- core/perf/ssd
- core/perf/ssd
- core/perf/zram-swap
- core/perf/zram-swap
- core/perf/zram-swap
- core/perf/zram-swap
- core/security
- core/security
- core/security
- core/security
- core/security/openssh
- core/security/openssh
- core/security/openssh
- core/security/openssh
- core/security/opkssh
- core/security/opkssh
- core/security/opkssh
- core/security/opkssh
- core/security/sudo
- core/security/sudo
- core/security/sudo
- core/security/sudo
- core/system/facter
- core/system/facter
- core/system/facter
- core/system/facter
- core/system/firmware
- core/system/firmware
- core/system/firmware
- core/system/firmware
- core/system/linux-kernel
- core/system/linux-kernel
- core/system/linux-kernel
- core/system/linux-kernel
- core/systemd
- core/systemd
- core/systemd
- core/systemd
- core/systemd/boot
- core/systemd/boot
- core/systemd/boot
- core/systemd/boot
- core/users
- core/users
- core/users
- core/users
- core/users/deterministic-uids
- core/users/deterministic-uids
- core/users/deterministic-uids
- core/users/deterministic-uids
- core/users/home-manager-shared
- core/users/home-manager-shared
- core/users/home-manager-shared
- core/users/home-manager-shared
- core/users/shell
- core/users/shell
- core/users/shell
- core/users/shell
- core/utils
- core/utils
- core/utils
- core/utils
- cortex
- cpu/amd
- desktop/gdm
- desktop/gnome
- desktop/uwsm
- desktop/xdg-portal
- desktop/xserver
- desktop/xwayland
- disk/zfs-diff
- disk/zfs-disk-single
- fonts/nerd-fonts
- fonts/regular
- gaming/emulation
- gaming/nix-ld
- gaming/sunshine
- gpu/amd
- gpu/nvidia-vfio
- hardware/adb
- hardware/audio
- hardware/bluetooth
- hardware/coolercontrol
- hardware/ddcutil
- hardware/gamepad
- hardware/keyboard
- hardware/performance
- hardware/vr-amd
- host/resolve(dev-gui)
- insecure-predicate/os
- media/easyeffects
- messaging/kdeconnect
- network/firewall-collector
- nix/remote-build-server
- opkssh-authz/shuo@blade
- opkssh-authz/shuo@cortex
- opkssh-authz/sini@axon-01
- opkssh-authz/sini@axon-02
- opkssh-authz/sini@axon-03
- opkssh-authz/sini@bitstream
- opkssh-authz/sini@blade
- opkssh-authz/sini@cortex
- opkssh-authz/sini@patch
- opkssh-authz/sini@slab
- opkssh-authz/sini@uplink
- opkssh-authz/vic@axon-01
- opkssh-authz/vic@axon-02
- opkssh-authz/vic@axon-03
- opkssh-authz/vic@bitstream
- opkssh-authz/vic@blade
- opkssh-authz/vic@cortex
- opkssh-authz/vic@uplink
- opkssh-authz/will@blade
- opkssh-authz/will@cortex
- provides/unfree(antigravity)
- provides/unfree(corefonts,vista-fonts)
- secrets/collector
- storage/media-data-share
- style/fonts
- style/stylix
- unfree-predicate/os
- user-enrich/shuo@blade
- user-enrich/shuo@cortex
- user-enrich/sini@axon-01
- user-enrich/sini@axon-02
- user-enrich/sini@axon-03
- user-enrich/sini@bitstream
- user-enrich/sini@blade
- user-enrich/sini@cortex
- user-enrich/sini@patch
- user-enrich/sini@slab
- user-enrich/sini@uplink
- user-enrich/vic@axon-01
- user-enrich/vic@axon-02
- user-enrich/vic@axon-03
- user-enrich/vic@bitstream
- user-enrich/vic@blade
- user-enrich/vic@cortex
- user-enrich/vic@uplink
- user-enrich/will@blade
- user-enrich/will@cortex
- virtualization/libvirt
- virtualization/microvm-host
- virtualization/podman
- virtualization/windows-vfio
- zfs-disk-single/root


## Providers

| Provider Aspect | Classes | Provider Path |
| ----------------- | --------- | --------------- |
| ai/beads |  | applications/dev/ai |
| ai/claude |  | applications/dev/ai |
| ai/hunk |  | applications/dev/ai |
| ai/llm-agents |  | applications/dev/ai |
| ai/ollama | nixos | services/ai |
| ai/rtk |  | applications/dev/ai |
| applications/browsers/firefox |  | applications/browsers |
| applications/browsers/firefox |  | applications/browsers |
| applications/gaming/steam | nixos | applications/gaming |
| applications/gaming/steam | nixos | applications/gaming |
| applications/media/spicetify |  | applications/media |
| applications/media/spicetify |  | applications/media |
| applications/shell/zsh |  | applications/shell |
| applications/shell/zsh |  | applications/shell |
| applications/shell/zsh |  | applications/shell |
| applications/shell/zsh |  | applications/shell |
| batteries/define-user |  | den/batteries |
| batteries/define-user/shuo@cortex | nixos | den/batteries |
| batteries/define-user/sini@cortex | nixos | den/batteries |
| batteries/define-user/vic@cortex | nixos | den/batteries |
| batteries/define-user/will@cortex | nixos | den/batteries |
| batteries/host-aspects |  | den/batteries |
| batteries/hostname |  | den/batteries |
| batteries/hostname/os | nixos | den/batteries |
| batteries/inputs' |  | den/batteries |
| batteries/inputs'/os | nixos | den/batteries |
| batteries/inputs'/user |  | den/batteries |
| batteries/primary-user(sini@axon-01) | nixos | den/batteries |
| batteries/primary-user(sini@axon-02) | nixos | den/batteries |
| batteries/primary-user(sini@axon-03) | nixos | den/batteries |
| batteries/primary-user(sini@bitstream) | nixos | den/batteries |
| batteries/primary-user(sini@blade) | nixos | den/batteries |
| batteries/primary-user(sini@cortex) | nixos | den/batteries |
| batteries/primary-user(sini@patch) | nixos | den/batteries |
| batteries/primary-user(sini@slab) | nixos | den/batteries |
| batteries/primary-user(sini@uplink) | nixos | den/batteries |
| batteries/self' |  | den/batteries |
| batteries/self'/os | nixos | den/batteries |
| batteries/self'/user |  | den/batteries |
| boot/network-initrd | nixos | core/boot |
| browsers/chromium |  | applications/browsers |
| codium/antigravity |  | applications/dev/editor/codium |
| codium/core |  | applications/dev/editor/codium |
| codium/vscode |  | applications/dev/editor/codium |
| core/impermanence | nixos | core |
| core/impermanence | nixos | core |
| core/impermanence | nixos | core |
| core/impermanence | nixos | core |
| core/impermanence/btrfs | nixos | core/impermanence |
| core/impermanence/btrfs | nixos | core/impermanence |
| core/impermanence/btrfs | nixos | core/impermanence |
| core/impermanence/btrfs | nixos | core/impermanence |
| core/impermanence/persist-collector | nixos | core/impermanence |
| core/impermanence/persist-collector | nixos | core/impermanence |
| core/impermanence/persist-collector | nixos | core/impermanence |
| core/impermanence/persist-collector | nixos | core/impermanence |
| core/impermanence/persist-home-collector |  | core/impermanence |
| core/impermanence/persist-home-collector |  | core/impermanence |
| core/impermanence/persist-home-collector |  | core/impermanence |
| core/impermanence/persist-home-collector |  | core/impermanence |
| core/impermanence/zfs | nixos | core/impermanence |
| core/impermanence/zfs | nixos | core/impermanence |
| core/impermanence/zfs | nixos | core/impermanence |
| core/impermanence/zfs | nixos | core/impermanence |
| core/localization/i18n | nixos | core/localization |
| core/localization/i18n | nixos | core/localization |
| core/localization/i18n | nixos | core/localization |
| core/localization/i18n | nixos | core/localization |
| core/localization/time |  | core/localization |
| core/localization/time |  | core/localization |
| core/localization/time |  | core/localization |
| core/localization/time |  | core/localization |
| core/network/hostsfile | nixos | core/network |
| core/network/hostsfile | nixos | core/network |
| core/network/hostsfile | nixos | core/network |
| core/network/hostsfile | nixos | core/network |
| core/network/networking | nixos | core/network |
| core/network/networking | nixos | core/network |
| core/network/networking | nixos | core/network |
| core/network/networking | nixos | core/network |
| core/network/syncthing/member |  | core/network/syncthing |
| core/network/syncthing/member |  | core/network/syncthing |
| core/network/syncthing/member |  | core/network/syncthing |
| core/network/syncthing/peer | nixos | core/network/syncthing |
| core/network/syncthing/peer | nixos | core/network/syncthing |
| core/network/syncthing/peer | nixos | core/network/syncthing |
| core/network/syncthing/peer | nixos | core/network/syncthing |
| core/network/tailscale | nixos | core/network |
| core/network/tailscale | nixos | core/network |
| core/network/tailscale | nixos | core/network |
| core/network/tailscale | nixos | core/network |
| core/nix | nixos | core |
| core/nix | nixos | core |
| core/nix | nixos | core |
| core/nix | nixos | core |
| core/nix/nixpkgs |  | core/nix |
| core/nix/nixpkgs |  | core/nix |
| core/nix/nixpkgs |  | core/nix |
| core/nix/nixpkgs |  | core/nix |
| core/nix/stateVersion | nixos | core/nix |
| core/nix/stateVersion | nixos | core/nix |
| core/nix/stateVersion | nixos | core/nix |
| core/nix/stateVersion | nixos | core/nix |
| core/perf/disable-docs | nixos | core/perf |
| core/perf/disable-docs | nixos | core/perf |
| core/perf/disable-docs | nixos | core/perf |
| core/perf/disable-docs | nixos | core/perf |
| core/perf/ssd | nixos | core/perf |
| core/perf/ssd | nixos | core/perf |
| core/perf/ssd | nixos | core/perf |
| core/perf/ssd | nixos | core/perf |
| core/perf/zram-swap | nixos | core/perf |
| core/perf/zram-swap | nixos | core/perf |
| core/perf/zram-swap | nixos | core/perf |
| core/perf/zram-swap | nixos | core/perf |
| core/security | nixos | core |
| core/security | nixos | core |
| core/security | nixos | core |
| core/security | nixos | core |
| core/security/openssh | nixos | core/security |
| core/security/openssh | nixos | core/security |
| core/security/openssh | nixos | core/security |
| core/security/openssh | nixos | core/security |
| core/security/opkssh | nixos | core/security |
| core/security/opkssh | nixos | core/security |
| core/security/opkssh | nixos | core/security |
| core/security/opkssh | nixos | core/security |
| core/security/sudo | nixos | core/security |
| core/security/sudo | nixos | core/security |
| core/security/sudo | nixos | core/security |
| core/security/sudo | nixos | core/security |
| core/system/facter | nixos | core/system |
| core/system/facter | nixos | core/system |
| core/system/facter | nixos | core/system |
| core/system/facter | nixos | core/system |
| core/system/firmware | nixos | core/system |
| core/system/firmware | nixos | core/system |
| core/system/firmware | nixos | core/system |
| core/system/firmware | nixos | core/system |
| core/system/linux-kernel | nixos | core/system |
| core/system/linux-kernel | nixos | core/system |
| core/system/linux-kernel | nixos | core/system |
| core/system/linux-kernel | nixos | core/system |
| core/systemd | nixos | core |
| core/systemd | nixos | core |
| core/systemd | nixos | core |
| core/systemd | nixos | core |
| core/systemd/boot | nixos | core/systemd |
| core/systemd/boot | nixos | core/systemd |
| core/systemd/boot | nixos | core/systemd |
| core/systemd/boot | nixos | core/systemd |
| core/users | nixos | core |
| core/users | nixos | core |
| core/users | nixos | core |
| core/users | nixos | core |
| core/users/deterministic-uids | nixos | core/users |
| core/users/deterministic-uids | nixos | core/users |
| core/users/deterministic-uids | nixos | core/users |
| core/users/deterministic-uids | nixos | core/users |
| core/users/home-manager-shared | nixos | core/users |
| core/users/home-manager-shared | nixos | core/users |
| core/users/home-manager-shared | nixos | core/users |
| core/users/home-manager-shared | nixos | core/users |
| core/users/resolved-user-emitter |  | core/users |
| core/users/resolved-user-emitter |  | core/users |
| core/users/resolved-user-emitter |  | core/users |
| core/users/resolved-user-emitter |  | core/users |
| core/users/shell | nixos | core/users |
| core/users/shell | nixos | core/users |
| core/users/shell | nixos | core/users |
| core/users/shell | nixos | core/users |
| core/utils | nixos | core |
| core/utils | nixos | core |
| core/utils | nixos | core |
| core/utils | nixos | core |
| cpu/amd | nixos | hardware/cpu |
| desktop/gdm | nixos | desktop |
| desktop/gnome | nixos | desktop |
| desktop/uwsm | nixos | desktop |
| desktop/xdg-portal | nixos | desktop |
| desktop/xserver | nixos | desktop |
| desktop/xwayland | nixos | desktop |
| disk/zfs-diff | nixos | disk |
| disk/zfs-disk-single | nixos | disk |
| editor/nvf |  | applications/dev/editor |
| fonts/nerd-fonts | nixos | desktop/style/fonts |
| fonts/regular | nixos | desktop/style/fonts |
| gaming/emulation | nixos | applications/gaming |
| gaming/mangohud |  | applications/gaming |
| gaming/nix-ld | nixos | applications/gaming |
| gaming/sunshine | nixos | applications/gaming |
| git/delta |  | applications/dev/git |
| git/github |  | applications/dev/git |
| git/lazygit |  | applications/dev/git |
| git/mergiraf |  | applications/dev/git |
| gpu/amd | nixos | hardware/gpu |
| gpu/nvidia-vfio | nixos | hardware/gpu |
| hardware/adb | nixos | hardware |
| hardware/audio | nixos | hardware |
| hardware/bluetooth | nixos | hardware |
| hardware/coolercontrol | nixos | hardware |
| hardware/ddcutil | nixos | hardware |
| hardware/gamepad | nixos | hardware |
| hardware/keyboard | nixos | hardware |
| hardware/performance | nixos | hardware |
| hardware/vr-amd | nixos | hardware |
| k8s/core |  | applications/dev/k8s |
| k8s/dev |  | applications/dev/k8s |
| k8s/helm |  | applications/dev/k8s |
| k8s/k9s |  | applications/dev/k8s |
| k8s/observability |  | applications/dev/k8s |
| k8s/plugins |  | applications/dev/k8s |
| k8s/security |  | applications/dev/k8s |
| k8s/tui |  | applications/dev/k8s |
| k8s/utils |  | applications/dev/k8s |
| lang/c |  | applications/dev/lang |
| lang/go |  | applications/dev/lang |
| lang/lua |  | applications/dev/lang |
| lang/markdown |  | applications/dev/lang |
| lang/nix |  | applications/dev/lang |
| lang/python |  | applications/dev/lang |
| lang/rust |  | applications/dev/lang |
| lang/shell |  | applications/dev/lang |
| mail/protonmail |  | applications/mail |
| mcp/codebase-memory |  | applications/dev/ai/mcp |
| media/easyeffects | nixos | applications/media |
| media/jellyfin-client |  | applications/media |
| media/mpv |  | applications/media |
| media/qbittorrent |  | applications/media |
| media/spotify-player |  | applications/media |
| media/youtube-music |  | applications/media |
| media/yt-dlp |  | applications/media |
| messaging/discord |  | applications/messaging |
| messaging/element |  | applications/messaging |
| messaging/kdeconnect | nixos | applications/messaging |
| messaging/messenger |  | applications/messaging |
| messaging/telegram |  | applications/messaging |
| messaging/zoom |  | applications/messaging |
| mux/herdr |  | applications/dev/mux |
| mux/sesh |  | applications/dev/mux |
| mux/tmux |  | applications/dev/mux |
| mux/zellij |  | applications/dev/mux |
| network/firewall-collector | nixos | core/network |
| nix/remote-build-server | nixos | services/nix |
| productivity/obs-studio |  | applications/productivity |
| productivity/obsidian |  | applications/productivity |
| productivity/zathura |  | applications/productivity |
| provides/unfree(antigravity) | nixos | den/provides |
| provides/unfree(corefonts,vista-fonts) | nixos | den/provides |
| roles/default |  | roles |
| roles/default |  | roles |
| roles/default |  | roles |
| roles/default |  | roles |
| roles/dev |  | roles |
| roles/dev-gui |  | roles |
| roles/gaming |  | roles |
| roles/inference |  | roles |
| roles/media |  | roles |
| roles/messaging |  | roles |
| roles/nix-builder |  | roles |
| roles/workstation |  | roles |
| secrets/agenix |  | secrets |
| secrets/agenix |  | secrets |
| secrets/agenix |  | secrets |
| secrets/agenix |  | secrets |
| secrets/collector | nixos | core/secrets |
| security/opkssh-client |  | applications/dev/security |
| security/ssh-agent-mux |  | applications/dev/security |
| shell/archive |  | applications/shell |
| shell/bat |  | applications/dev/shell |
| shell/bottom |  | applications/dev/shell |
| shell/btop |  | applications/dev/shell |
| shell/data |  | applications/shell |
| shell/direnv |  | applications/dev/shell |
| shell/disk |  | applications/shell |
| shell/eza |  | applications/dev/shell |
| shell/nix-index |  | applications/shell |
| shell/process |  | applications/shell |
| shell/search |  | applications/shell |
| shell/starship |  | applications/dev/shell |
| shell/yazi |  | applications/shell |
| shell/zoxide |  | applications/shell |
| storage/media-data-share | nixos | services/storage |
| style/fonts | nixos | desktop/style |
| style/stylix | nixos | desktop/style |
| syncthing/tray |  | core/network/syncthing |
| terminals/alacritty |  | applications/terminals |
| terminals/kitty |  | applications/terminals |
| virtualization/containers |  | virtualization |
| virtualization/libvirt | nixos | virtualization |
| virtualization/microvm-host | nixos | virtualization |
| virtualization/podman | nixos | virtualization |
| virtualization/windows-vfio | nixos | virtualization |
| zfs-disk-single/root | nixos | disk/zfs-disk-single |

## Policies

- **broadcast-syncthing-hub-shares** (from: user)
- **broadcast-syncthing-hub-shares** (from: user)
- **broadcast-syncthing-hub-shares** (from: user)
- **broadcast-syncthing-hub-shares** (from: user)
- **broadcast-syncthing-peers** (from: user)
- **broadcast-syncthing-peers** (from: user)
- **broadcast-syncthing-peers** (from: user)
- **broadcast-syncthing-peers** (from: user)
- **broadcast-syncthing-peers-to-hub** (from: user)
- **broadcast-syncthing-peers-to-hub** (from: user)
- **broadcast-syncthing-peers-to-hub** (from: user)
- **broadcast-syncthing-peers-to-hub** (from: user)
- **collect-bgp-peers** (from: host)
- **collect-container-registries** (from: host)
- **collect-host-addrs** (from: host)
- **collect-k3s-nodes** (from: host)
- **collect-ollama-endpoints** (from: host)
- **collect-prometheus-targets** (from: host)
- **collect-thunderbolt-mesh-peers** (from: host)
- **collect-vault-peers** (from: host)
- **droidHm-user-detect** (from: user)
- **drop-user-to-host-on-droid** (from: user)
- **env-users** (from: host)
- **expose-resolved-users** (from: user)
- **expose-resolved-users** (from: user)
- **expose-resolved-users** (from: user)
- **expose-resolved-users** (from: user)
- **hm-user-detect** (from: user)
- **hm-user-detect** (from: user)
- **hm-user-detect** (from: user)
- **hm-user-detect** (from: user)
- **homeAarch64-to-hm** (from: user)
- **homeDarwin-to-hm** (from: user)
- **homeLinux-to-hm** (from: user)
- **homeLinux-to-hm** (from: user)
- **homeLinux-to-hm** (from: user)
- **homeLinux-to-hm** (from: user)
- **host-aspects-project** (from: user)
- **host-modules-capture** (from: host)
- **os-to-host** (from: user)
- **os-to-host** (from: user)
- **os-to-host** (from: user)
- **os-to-host** (from: user)
- **os-to-host** (from: host)
- **primary-user-for-owner** (from: user)
- **user-aspect-auto-include** (from: user)
- **user-aspect-auto-include** (from: user)
- **user-to-host** (from: user)
- **user-to-host** (from: user)
- **user-to-host** (from: user)
- **user-to-host** (from: user)

## Pipe Data

**Produces:** none
**Collects:** none
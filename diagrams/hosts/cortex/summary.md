# Host: cortex

## Overview

- **72** aspects across **2** classes (nixos, homeManager)
- **122** provider sub-aspects
- **8** policies fired
- **1** entity instances

## Aspects

| Aspect | Classes | Parametric | Instance |
| -------- | --------- | ------------ | ---------- |
| apps/easyeffects | nixos, homeManager | no | host:cortex |
| apps/emulation | nixos, homeManager | no | host:cortex |
| apps/gpg | nixos, homeManager | no | host:cortex |
| apps/kdeconnect | nixos, homeManager | no | host:cortex |
| apps/steam | nixos, homeManager | no | host:cortex |
| apps/sunshine | nixos, homeManager | no | host:cortex |
| apps/wireshark | nixos, homeManager | no | host:cortex |
| batteries/hostname/os | nixos | yes (host) | host:cortex |
| core/deterministic-uids | nixos | no | host:cortex |
| core/facter | nixos | no | host:cortex |
| core/firewall-collector | nixos | no | host:cortex |
| core/firmware | nixos | no | host:cortex |
| core/home-manager | nixos | no | host:cortex |
| core/i18n | nixos | no | host:cortex |
| core/linux-kernel | nixos | no | host:cortex |
| core/lix | nixos | no | host:cortex |
| core/nix | nixos | no | host:cortex |
| core/nix-remote-build-client | nixos | no | host:cortex |
| core/persist-collector | nixos | no | host:cortex |
| core/secrets-collector | nixos | no | host:cortex |
| core/security | nixos | no | host:cortex |
| core/shell | nixos | no | host:cortex |
| core/ssd | nixos | no | host:cortex |
| core/stateVersion | nixos | no | host:cortex |
| core/sudo | nixos | no | host:cortex |
| core/systemd | nixos | no | host:cortex |
| core/systemd-boot | nixos | no | host:cortex |
| core/users | nixos | no | host:cortex |
| core/utils | nixos | no | host:cortex |
| cortex | nixos | yes (host) | host:cortex |
| desktop/fonts | nixos, homeManager | no | host:cortex |
| desktop/gdm | nixos | no | host:cortex |
| desktop/gnome | nixos, homeManager | no | host:cortex |
| desktop/hyprland | nixos, homeManager | no | host:cortex |
| desktop/stylix | nixos, homeManager | no | host:cortex |
| desktop/uwsm | nixos | no | host:cortex |
| desktop/xdg-portal | nixos | no | host:cortex |
| desktop/xserver | nixos | no | host:cortex |
| desktop/xwayland | nixos | no | host:cortex |
| disk/impermanence | nixos, homeManager | no | host:cortex |
| disk/zfs-diff | nixos | no | host:cortex |
| disk/zfs-disk-single | nixos | no | host:cortex |
| hardware/adb | nixos | no | host:cortex |
| hardware/audio | nixos, homeManager | no | host:cortex |
| hardware/bluetooth | nixos, homeManager | no | host:cortex |
| hardware/coolercontrol | nixos | no | host:cortex |
| hardware/cpu-amd | nixos | no | host:cortex |
| hardware/ddcutil | nixos | no | host:cortex |
| hardware/gamepad | nixos | no | host:cortex |
| hardware/gpu-amd | nixos | no | host:cortex |
| hardware/gpu-nvidia | nixos | no | host:cortex |
| hardware/gpu-nvidia-vfio | nixos | no | host:cortex |
| hardware/keyboard | nixos | no | host:cortex |
| hardware/performance | nixos | no | host:cortex |
| hardware/vr-amd | nixos, homeManager | no | host:cortex |
| insecure-predicate/os | nixos | yes (host) | host:cortex |
| network/hosts | nixos | no | host:cortex |
| network/network-boot | nixos | no | host:cortex |
| network/networking | nixos | no | host:cortex |
| network/openssh | nixos | no | host:cortex |
| services/media-data-share | nixos | no | host:cortex |
| services/nix-remote-build-server | nixos | no | host:cortex |
| services/ollama | nixos | no | host:cortex |
| services/tailscale | nixos | no | host:cortex |
| system/nix-ld | nixos | no | host:cortex |
| unfree-predicate/os | nixos | yes (host) | host:cortex |
| virtualization/libvirt | nixos, homeManager | no | host:cortex |
| virtualization/microvm | nixos | no | host:cortex |
| virtualization/microvm-cuda | nixos | no | host:cortex |
| virtualization/podman | nixos | no | host:cortex |
| virtualization/windows-vfio | nixos | no | host:cortex |
| zfs-disk-single/root | nixos | no | host:cortex |

## Classes

### nixos (72)

- apps/easyeffects
- apps/emulation
- apps/gpg
- apps/kdeconnect
- apps/steam
- apps/sunshine
- apps/wireshark
- batteries/hostname/os
- core/deterministic-uids
- core/facter
- core/firewall-collector
- core/firmware
- core/home-manager
- core/i18n
- core/linux-kernel
- core/lix
- core/nix
- core/nix-remote-build-client
- core/persist-collector
- core/secrets-collector
- core/security
- core/shell
- core/ssd
- core/stateVersion
- core/sudo
- core/systemd
- core/systemd-boot
- core/users
- core/utils
- cortex
- desktop/fonts
- desktop/gdm
- desktop/gnome
- desktop/hyprland
- desktop/stylix
- desktop/uwsm
- desktop/xdg-portal
- desktop/xserver
- desktop/xwayland
- disk/impermanence
- disk/zfs-diff
- disk/zfs-disk-single
- hardware/adb
- hardware/audio
- hardware/bluetooth
- hardware/coolercontrol
- hardware/cpu-amd
- hardware/ddcutil
- hardware/gamepad
- hardware/gpu-amd
- hardware/gpu-nvidia
- hardware/gpu-nvidia-vfio
- hardware/keyboard
- hardware/performance
- hardware/vr-amd
- insecure-predicate/os
- network/hosts
- network/network-boot
- network/networking
- network/openssh
- services/media-data-share
- services/nix-remote-build-server
- services/ollama
- services/tailscale
- system/nix-ld
- unfree-predicate/os
- virtualization/libvirt
- virtualization/microvm
- virtualization/microvm-cuda
- virtualization/podman
- virtualization/windows-vfio
- zfs-disk-single/root


### homeManager (16)

- apps/easyeffects
- apps/emulation
- apps/gpg
- apps/kdeconnect
- apps/steam
- apps/sunshine
- apps/wireshark
- desktop/fonts
- desktop/gnome
- desktop/hyprland
- desktop/stylix
- disk/impermanence
- hardware/audio
- hardware/bluetooth
- hardware/vr-amd
- virtualization/libvirt


## Providers

| Provider Aspect | Classes | Provider Path |
| ----------------- | --------- | --------------- |
| apps/alacritty | homeManager | apps |
| apps/bat | homeManager | apps |
| apps/claude | homeManager | apps |
| apps/direnv | homeManager | apps |
| apps/discord | homeManager | apps |
| apps/easyeffects | nixos, homeManager | apps |
| apps/emulation | nixos, homeManager | apps |
| apps/eza | homeManager | apps |
| apps/firefox | homeManager | apps |
| apps/git | homeManager | apps |
| apps/gitkraken | homeManager | apps |
| apps/gpg | nixos, homeManager | apps |
| apps/jellyfin-client | homeManager | apps |
| apps/k9s | homeManager | apps |
| apps/kdeconnect | nixos, homeManager | apps |
| apps/kitty | homeManager | apps |
| apps/kube-tools | homeManager | apps |
| apps/mangohud | homeManager | apps |
| apps/misc-tools | homeManager | apps |
| apps/mpv | homeManager | apps |
| apps/nix-index | homeManager | apps |
| apps/nvf | homeManager | apps |
| apps/obs-studio | homeManager | apps |
| apps/obsidian | homeManager | apps |
| apps/python | homeManager | apps |
| apps/qbittorrent | homeManager | apps |
| apps/spicetify | homeManager | apps |
| apps/ssh | homeManager | apps |
| apps/starship | homeManager | apps |
| apps/steam | nixos, homeManager | apps |
| apps/sunshine | nixos, homeManager | apps |
| apps/sysmon | homeManager | apps |
| apps/telegram | homeManager | apps |
| apps/vscode | homeManager | apps |
| apps/wireshark | nixos, homeManager | apps |
| apps/yazi | homeManager | apps |
| apps/youtube-music | homeManager | apps |
| apps/yt-dlp | homeManager | apps |
| apps/zathura | homeManager | apps |
| apps/zellij | homeManager | apps |
| apps/zoom | homeManager | apps |
| apps/zoxide | homeManager | apps |
| apps/zsh | homeManager | apps |
| batteries/define-user |  | den/batteries |
| batteries/host/resolve(define-user):den/batteries |  | den/batteries |
| batteries/hostname |  | den/batteries |
| batteries/hostname/os | nixos | den/batteries |
| batteries/primary-user |  | den/batteries |
| core/default |  | core |
| core/deterministic-uids | nixos | core |
| core/facter | nixos | core |
| core/firewall-collector | nixos | core |
| core/firmware | nixos | core |
| core/home-manager | nixos | core |
| core/i18n | nixos | core |
| core/linux-kernel | nixos | core |
| core/lix | nixos | core |
| core/nix | nixos | core |
| core/nix-remote-build-client | nixos | core |
| core/nixpkgs |  | core |
| core/persist-collector | nixos | core |
| core/persist-home-collector | homeManager | core |
| core/secrets-collector | nixos | core |
| core/security | nixos | core |
| core/shell | nixos | core |
| core/ssd | nixos | core |
| core/stateVersion | nixos | core |
| core/sudo | nixos | core |
| core/systemd | nixos | core |
| core/systemd-boot | nixos | core |
| core/time |  | core |
| core/users | nixos | core |
| core/utils | nixos | core |
| desktop/fonts | nixos, homeManager | desktop |
| desktop/gdm | nixos | desktop |
| desktop/gnome | nixos, homeManager | desktop |
| desktop/hyprland | nixos, homeManager | desktop |
| desktop/stylix | nixos, homeManager | desktop |
| desktop/uwsm | nixos | desktop |
| desktop/xdg-portal | nixos | desktop |
| desktop/xserver | nixos | desktop |
| desktop/xwayland | nixos | desktop |
| disk/impermanence | nixos, homeManager | disk |
| disk/zfs-diff | nixos | disk |
| disk/zfs-disk-single | nixos | disk |
| hardware/adb | nixos | hardware |
| hardware/audio | nixos, homeManager | hardware |
| hardware/bluetooth | nixos, homeManager | hardware |
| hardware/coolercontrol | nixos | hardware |
| hardware/cpu-amd | nixos | hardware |
| hardware/ddcutil | nixos | hardware |
| hardware/gamepad | nixos | hardware |
| hardware/gpu-amd | nixos | hardware |
| hardware/gpu-nvidia | nixos | hardware |
| hardware/gpu-nvidia-vfio | nixos | hardware |
| hardware/keyboard | nixos | hardware |
| hardware/performance | nixos | hardware |
| hardware/vr-amd | nixos, homeManager | hardware |
| network/hosts | nixos | network |
| network/network-boot | nixos | network |
| network/networking | nixos | network |
| network/openssh | nixos | network |
| roles/dev |  | roles |
| roles/dev-gui |  | roles |
| roles/gaming |  | roles |
| roles/inference |  | roles |
| roles/media |  | roles |
| roles/messaging |  | roles |
| roles/nix-builder |  | roles |
| roles/workstation | homeManager | roles |
| secrets/agenix |  | secrets |
| services/media-data-share | nixos | services |
| services/nix-remote-build-server | nixos | services |
| services/ollama | nixos | services |
| services/tailscale | nixos | services |
| system/nix-ld | nixos | system |
| virtualization/libvirt | nixos, homeManager | virtualization |
| virtualization/microvm | nixos | virtualization |
| virtualization/microvm-cuda | nixos | virtualization |
| virtualization/podman | nixos | virtualization |
| virtualization/windows-vfio | nixos | virtualization |
| zfs-disk-single/root | nixos | disk/zfs-disk-single |

## Policies

- **collect-bgp-peers** (from: host)
- **collect-host-addrs** (from: host)
- **collect-k3s-nodes** (from: host)
- **collect-ollama-endpoints** (from: host)
- **collect-prometheus-targets** (from: host)
- **collect-thunderbolt-mesh-peers** (from: host)
- **collect-vault-peers** (from: host)
- **os-to-host** (from: host)

## Pipe Data

**Produces:** none
**Collects:** none
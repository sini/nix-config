# Host: blade

## Overview

- **66** aspects across **2** classes (nixos, homeManager)
- **111** provider sub-aspects
- **8** policies fired
- **1** entity instances

## Aspects

| Aspect                       | Classes            | Parametric | Instance   |
| ---------------------------- | ------------------ | ---------- | ---------- |
| apps/emulation               | nixos, homeManager | no         | host:blade |
| apps/gpg                     | nixos, homeManager | no         | host:blade |
| apps/steam                   | nixos, homeManager | no         | host:blade |
| apps/sunshine                | nixos, homeManager | no         | host:blade |
| apps/wireshark               | nixos, homeManager | no         | host:blade |
| batteries/hostname/os        | nixos              | yes (host) | host:blade |
| blade                        | nixos              | yes (host) | host:blade |
| core/deterministic-uids      | nixos              | no         | host:blade |
| core/facter                  | nixos              | no         | host:blade |
| core/firewall-collector      | nixos              | no         | host:blade |
| core/firmware                | nixos              | no         | host:blade |
| core/home-manager            | nixos              | no         | host:blade |
| core/i18n                    | nixos              | no         | host:blade |
| core/linux-kernel            | nixos              | no         | host:blade |
| core/lix                     | nixos              | no         | host:blade |
| core/nix                     | nixos              | no         | host:blade |
| core/nix-remote-build-client | nixos              | no         | host:blade |
| core/persist-collector       | nixos              | no         | host:blade |
| core/secrets-collector       | nixos              | no         | host:blade |
| core/security                | nixos              | no         | host:blade |
| core/shell                   | nixos              | no         | host:blade |
| core/ssd                     | nixos              | no         | host:blade |
| core/stateVersion            | nixos              | no         | host:blade |
| core/sudo                    | nixos              | no         | host:blade |
| core/systemd                 | nixos              | no         | host:blade |
| core/systemd-boot            | nixos              | no         | host:blade |
| core/users                   | nixos              | no         | host:blade |
| core/utils                   | nixos              | no         | host:blade |
| desktop/fonts                | nixos, homeManager | no         | host:blade |
| desktop/gdm                  | nixos              | no         | host:blade |
| desktop/gnome                | nixos, homeManager | no         | host:blade |
| desktop/hyprland             | nixos, homeManager | no         | host:blade |
| desktop/stylix               | nixos, homeManager | no         | host:blade |
| desktop/uwsm                 | nixos              | no         | host:blade |
| desktop/xdg-portal           | nixos              | no         | host:blade |
| desktop/xserver              | nixos              | no         | host:blade |
| desktop/xwayland             | nixos              | no         | host:blade |
| disk/impermanence            | nixos, homeManager | no         | host:blade |
| disk/zfs-diff                | nixos              | no         | host:blade |
| disk/zfs-disk-single         | nixos              | no         | host:blade |
| hardware/adb                 | nixos              | no         | host:blade |
| hardware/audio               | nixos, homeManager | no         | host:blade |
| hardware/bluetooth           | nixos, homeManager | no         | host:blade |
| hardware/coolercontrol       | nixos              | no         | host:blade |
| hardware/cpu-intel           | nixos              | no         | host:blade |
| hardware/ddcutil             | nixos              | no         | host:blade |
| hardware/gamepad             | nixos              | no         | host:blade |
| hardware/gpu-intel           | nixos              | no         | host:blade |
| hardware/gpu-nvidia          | nixos              | no         | host:blade |
| hardware/gpu-nvidia-prime    | nixos              | no         | host:blade |
| hardware/keyboard            | nixos              | no         | host:blade |
| hardware/performance         | nixos              | no         | host:blade |
| hardware/razer               | nixos              | no         | host:blade |
| insecure-predicate/os        | nixos              | yes (host) | host:blade |
| network/hosts                | nixos              | no         | host:blade |
| network/network-boot         | nixos              | no         | host:blade |
| network/network-manager      | nixos              | no         | host:blade |
| network/networking           | nixos              | no         | host:blade |
| network/openssh              | nixos              | no         | host:blade |
| network/wireless             | nixos, homeManager | no         | host:blade |
| roles/laptop                 | nixos              | no         | host:blade |
| services/tailscale           | nixos              | no         | host:blade |
| system/nix-ld                | nixos              | no         | host:blade |
| unfree-predicate/os          | nixos              | yes (host) | host:blade |
| virtualization/libvirt       | nixos, homeManager | no         | host:blade |
| zfs-disk-single/root         | nixos              | no         | host:blade |

## Classes

### nixos (66)

- apps/emulation
- apps/gpg
- apps/steam
- apps/sunshine
- apps/wireshark
- batteries/hostname/os
- blade
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
- hardware/cpu-intel
- hardware/ddcutil
- hardware/gamepad
- hardware/gpu-intel
- hardware/gpu-nvidia
- hardware/gpu-nvidia-prime
- hardware/keyboard
- hardware/performance
- hardware/razer
- insecure-predicate/os
- network/hosts
- network/network-boot
- network/network-manager
- network/networking
- network/openssh
- network/wireless
- roles/laptop
- services/tailscale
- system/nix-ld
- unfree-predicate/os
- virtualization/libvirt
- zfs-disk-single/root

### homeManager (14)

- apps/emulation
- apps/gpg
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
- network/wireless
- virtualization/libvirt

## Providers

| Provider Aspect                                   | Classes            | Provider Path        |
| ------------------------------------------------- | ------------------ | -------------------- |
| apps/alacritty                                    | homeManager        | apps                 |
| apps/bat                                          | homeManager        | apps                 |
| apps/claude                                       | homeManager        | apps                 |
| apps/direnv                                       | homeManager        | apps                 |
| apps/discord                                      | homeManager        | apps                 |
| apps/emulation                                    | nixos, homeManager | apps                 |
| apps/eza                                          | homeManager        | apps                 |
| apps/firefox                                      | homeManager        | apps                 |
| apps/git                                          | homeManager        | apps                 |
| apps/gitkraken                                    | homeManager        | apps                 |
| apps/gpg                                          | nixos, homeManager | apps                 |
| apps/jellyfin-client                              | homeManager        | apps                 |
| apps/k9s                                          | homeManager        | apps                 |
| apps/kitty                                        | homeManager        | apps                 |
| apps/kube-tools                                   | homeManager        | apps                 |
| apps/mangohud                                     | homeManager        | apps                 |
| apps/misc-tools                                   | homeManager        | apps                 |
| apps/mpv                                          | homeManager        | apps                 |
| apps/nix-index                                    | homeManager        | apps                 |
| apps/nvf                                          | homeManager        | apps                 |
| apps/obs-studio                                   | homeManager        | apps                 |
| apps/obsidian                                     | homeManager        | apps                 |
| apps/python                                       | homeManager        | apps                 |
| apps/qbittorrent                                  | homeManager        | apps                 |
| apps/spicetify                                    | homeManager        | apps                 |
| apps/ssh                                          | homeManager        | apps                 |
| apps/starship                                     | homeManager        | apps                 |
| apps/steam                                        | nixos, homeManager | apps                 |
| apps/sunshine                                     | nixos, homeManager | apps                 |
| apps/sysmon                                       | homeManager        | apps                 |
| apps/vscode                                       | homeManager        | apps                 |
| apps/wireshark                                    | nixos, homeManager | apps                 |
| apps/yazi                                         | homeManager        | apps                 |
| apps/youtube-music                                | homeManager        | apps                 |
| apps/yt-dlp                                       | homeManager        | apps                 |
| apps/zathura                                      | homeManager        | apps                 |
| apps/zellij                                       | homeManager        | apps                 |
| apps/zoxide                                       | homeManager        | apps                 |
| apps/zsh                                          | homeManager        | apps                 |
| batteries/define-user                             |                    | den/batteries        |
| batteries/host/resolve(define-user):den/batteries |                    | den/batteries        |
| batteries/hostname                                |                    | den/batteries        |
| batteries/hostname/os                             | nixos              | den/batteries        |
| batteries/primary-user                            |                    | den/batteries        |
| core/default                                      |                    | core                 |
| core/deterministic-uids                           | nixos              | core                 |
| core/facter                                       | nixos              | core                 |
| core/firewall-collector                           | nixos              | core                 |
| core/firmware                                     | nixos              | core                 |
| core/home-manager                                 | nixos              | core                 |
| core/i18n                                         | nixos              | core                 |
| core/linux-kernel                                 | nixos              | core                 |
| core/lix                                          | nixos              | core                 |
| core/nix                                          | nixos              | core                 |
| core/nix-remote-build-client                      | nixos              | core                 |
| core/nixpkgs                                      |                    | core                 |
| core/persist-collector                            | nixos              | core                 |
| core/persist-home-collector                       | homeManager        | core                 |
| core/secrets-collector                            | nixos              | core                 |
| core/security                                     | nixos              | core                 |
| core/shell                                        | nixos              | core                 |
| core/ssd                                          | nixos              | core                 |
| core/stateVersion                                 | nixos              | core                 |
| core/sudo                                         | nixos              | core                 |
| core/systemd                                      | nixos              | core                 |
| core/systemd-boot                                 | nixos              | core                 |
| core/time                                         |                    | core                 |
| core/users                                        | nixos              | core                 |
| core/utils                                        | nixos              | core                 |
| desktop/fonts                                     | nixos, homeManager | desktop              |
| desktop/gdm                                       | nixos              | desktop              |
| desktop/gnome                                     | nixos, homeManager | desktop              |
| desktop/hyprland                                  | nixos, homeManager | desktop              |
| desktop/stylix                                    | nixos, homeManager | desktop              |
| desktop/uwsm                                      | nixos              | desktop              |
| desktop/xdg-portal                                | nixos              | desktop              |
| desktop/xserver                                   | nixos              | desktop              |
| desktop/xwayland                                  | nixos              | desktop              |
| disk/impermanence                                 | nixos, homeManager | disk                 |
| disk/zfs-diff                                     | nixos              | disk                 |
| disk/zfs-disk-single                              | nixos              | disk                 |
| hardware/adb                                      | nixos              | hardware             |
| hardware/audio                                    | nixos, homeManager | hardware             |
| hardware/bluetooth                                | nixos, homeManager | hardware             |
| hardware/coolercontrol                            | nixos              | hardware             |
| hardware/cpu-intel                                | nixos              | hardware             |
| hardware/ddcutil                                  | nixos              | hardware             |
| hardware/gamepad                                  | nixos              | hardware             |
| hardware/gpu-intel                                | nixos              | hardware             |
| hardware/gpu-nvidia                               | nixos              | hardware             |
| hardware/gpu-nvidia-prime                         | nixos              | hardware             |
| hardware/keyboard                                 | nixos              | hardware             |
| hardware/performance                              | nixos              | hardware             |
| hardware/razer                                    | nixos              | hardware             |
| network/hosts                                     | nixos              | network              |
| network/network-boot                              | nixos              | network              |
| network/network-manager                           | nixos              | network              |
| network/networking                                | nixos              | network              |
| network/openssh                                   | nixos              | network              |
| network/wireless                                  | nixos, homeManager | network              |
| roles/dev                                         |                    | roles                |
| roles/dev-gui                                     |                    | roles                |
| roles/gaming                                      |                    | roles                |
| roles/laptop                                      | nixos              | roles                |
| roles/media                                       |                    | roles                |
| roles/workstation                                 | homeManager        | roles                |
| secrets/agenix                                    |                    | secrets              |
| services/tailscale                                | nixos              | services             |
| system/nix-ld                                     | nixos              | system               |
| virtualization/libvirt                            | nixos, homeManager | virtualization       |
| zfs-disk-single/root                              | nixos              | disk/zfs-disk-single |

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

**Produces:** none **Collects:** none

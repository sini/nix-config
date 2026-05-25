# Host: patch

## Overview

- **29** aspects across **2** classes (nixos, homeManager)
- **56** provider sub-aspects
- **14** policies fired
- **2** entity instances

## Aspects

| Aspect | Classes | Parametric | Instance |
| -------- | --------- | ------------ | ---------- |
| apps/gpg | nixos, homeManager | no | host:patch |
| batteries/define-user/sini@patch | nixos, homeManager | yes (host, user) | host:patch |
| batteries/primary-user(sini@patch) | nixos | yes (host, user) | host:patch |
| core/deterministic-uids | nixos | no | host:patch |
| core/facter | nixos | no | host:patch |
| core/firewall-collector | nixos | no | host:patch |
| core/firmware | nixos | no | host:patch |
| core/home-manager | nixos | no | host:patch |
| core/i18n | nixos | no | host:patch |
| core/linux-kernel | nixos | no | host:patch |
| core/lix | nixos | no | host:patch |
| core/nix | nixos | no | host:patch |
| core/nix-remote-build-client | nixos | no | host:patch |
| core/secrets-collector | nixos | no | host:patch |
| core/security | nixos | no | host:patch |
| core/shell | nixos | no | host:patch |
| core/ssd | nixos | no | host:patch |
| core/stateVersion | nixos | no | host:patch |
| core/sudo | nixos | no | host:patch |
| core/systemd | nixos | no | host:patch |
| core/systemd-boot | nixos | no | host:patch |
| core/users | nixos | no | host:patch |
| core/utils | nixos | no | host:patch |
| hardware/adb | nixos | no | host:patch |
| network/hosts | nixos | no | host:patch |
| network/networking | nixos | no | host:patch |
| network/openssh | nixos | no | host:patch |
| services/tailscale | nixos | no | host:patch |
| user-enrich/sini@patch | nixos | yes (host, user) | user:sini |

## Classes

### nixos (29)

- apps/gpg
- batteries/define-user/sini@patch
- batteries/primary-user(sini@patch)
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
- hardware/adb
- network/hosts
- network/networking
- network/openssh
- services/tailscale
- user-enrich/sini@patch


### homeManager (2)

- apps/gpg
- batteries/define-user/sini@patch


## Providers

| Provider Aspect | Classes | Provider Path |
| ----------------- | --------- | --------------- |
| apps/bat | homeManager | apps |
| apps/claude | homeManager | apps |
| apps/direnv | homeManager | apps |
| apps/eza | homeManager | apps |
| apps/git | homeManager | apps |
| apps/gpg | nixos, homeManager | apps |
| apps/k9s | homeManager | apps |
| apps/misc-tools | homeManager | apps |
| apps/nix-index | homeManager | apps |
| apps/nvf | homeManager | apps |
| apps/python | homeManager | apps |
| apps/ssh | homeManager | apps |
| apps/starship | homeManager | apps |
| apps/sysmon | homeManager | apps |
| apps/yazi | homeManager | apps |
| apps/zoxide | homeManager | apps |
| apps/zsh | homeManager | apps |
| batteries/define-user |  | den/batteries |
| batteries/define-user/sini@patch | nixos, homeManager | den/batteries |
| batteries/host-aspects |  | den/batteries |
| batteries/host-aspects/sini@patch | homeManager | den/batteries |
| batteries/host/resolve(define-user):den/batteries |  | den/batteries |
| batteries/hostname |  | den/batteries |
| batteries/hostname/os |  | den/batteries |
| batteries/primary-user |  | den/batteries |
| batteries/primary-user(sini@patch) | nixos | den/batteries |
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
| core/resolved-user-emitter |  | core |
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
| hardware/adb | nixos | hardware |
| network/hosts | nixos | network |
| network/networking | nixos | network |
| network/openssh | nixos | network |
| roles/dev |  | roles |
| services/tailscale | nixos | services |

## Policies

- **collect-bgp-peers** (from: host)
- **collect-host-addrs** (from: host)
- **collect-k3s-nodes** (from: host)
- **collect-ollama-endpoints** (from: host)
- **collect-prometheus-targets** (from: host)
- **collect-thunderbolt-mesh-peers** (from: host)
- **collect-vault-peers** (from: host)
- **hm-user-detect** (from: user)
- **homeAarch64-to-hm** (from: user)
- **homeDarwin-to-hm** (from: user)
- **host-to-hm-users** (from: host)
- **os-to-host** (from: host)
- **os-to-host** (from: user)
- **user-to-host** (from: user)

## Pipe Data

**Produces:** none
**Collects:** none
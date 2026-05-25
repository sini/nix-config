# Host: bitstream

## Overview

- **42** aspects across **2** classes (nixos, homeManager)
- **50** provider sub-aspects
- **8** policies fired
- **1** entity instances

## Aspects

| Aspect                           | Classes            | Parametric | Instance       |
| -------------------------------- | ------------------ | ---------- | -------------- |
| batteries/hostname/os            | nixos              | yes (host) | host:bitstream |
| bitstream                        | nixos              | yes (host) | host:bitstream |
| core/deterministic-uids          | nixos              | no         | host:bitstream |
| core/facter                      | nixos              | no         | host:bitstream |
| core/firewall-collector          | nixos              | no         | host:bitstream |
| core/firmware                    | nixos              | no         | host:bitstream |
| core/home-manager                | nixos              | no         | host:bitstream |
| core/i18n                        | nixos              | no         | host:bitstream |
| core/linux-kernel                | nixos              | no         | host:bitstream |
| core/lix                         | nixos              | no         | host:bitstream |
| core/nix                         | nixos              | no         | host:bitstream |
| core/nix-remote-build-client     | nixos              | no         | host:bitstream |
| core/persist-collector           | nixos              | no         | host:bitstream |
| core/secrets-collector           | nixos              | no         | host:bitstream |
| core/security                    | nixos              | no         | host:bitstream |
| core/shell                       | nixos              | no         | host:bitstream |
| core/ssd                         | nixos              | no         | host:bitstream |
| core/stateVersion                | nixos              | no         | host:bitstream |
| core/sudo                        | nixos              | no         | host:bitstream |
| core/systemd                     | nixos              | no         | host:bitstream |
| core/systemd-boot                | nixos              | no         | host:bitstream |
| core/users                       | nixos              | no         | host:bitstream |
| core/utils                       | nixos              | no         | host:bitstream |
| disk/impermanence                | nixos, homeManager | no         | host:bitstream |
| disk/zfs-diff                    | nixos              | no         | host:bitstream |
| disk/zfs-disk-single             | nixos              | no         | host:bitstream |
| hardware/cpu-amd                 | nixos              | no         | host:bitstream |
| hardware/gpu-amd                 | nixos              | no         | host:bitstream |
| insecure-predicate/os            | nixos              | yes (host) | host:bitstream |
| network/hosts                    | nixos              | no         | host:bitstream |
| network/network-boot             | nixos              | no         | host:bitstream |
| network/networking               | nixos              | no         | host:bitstream |
| network/openssh                  | nixos              | no         | host:bitstream |
| roles/server                     | nixos              | no         | host:bitstream |
| services/acme                    | nixos              | no         | host:bitstream |
| services/media-data-share        | nixos              | no         | host:bitstream |
| services/nix-remote-build-server | nixos              | no         | host:bitstream |
| services/prometheus-exporter     | nixos              | no         | host:bitstream |
| services/tailscale               | nixos              | no         | host:bitstream |
| services/tang                    | nixos              | no         | host:bitstream |
| unfree-predicate/os              | nixos              | yes (host) | host:bitstream |
| zfs-disk-single/root             | nixos              | no         | host:bitstream |

## Classes

### nixos (42)

- batteries/hostname/os
- bitstream
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
- disk/impermanence
- disk/zfs-diff
- disk/zfs-disk-single
- hardware/cpu-amd
- hardware/gpu-amd
- insecure-predicate/os
- network/hosts
- network/network-boot
- network/networking
- network/openssh
- roles/server
- services/acme
- services/media-data-share
- services/nix-remote-build-server
- services/prometheus-exporter
- services/tailscale
- services/tang
- unfree-predicate/os
- zfs-disk-single/root

### homeManager (1)

- disk/impermanence

## Providers

| Provider Aspect                                   | Classes            | Provider Path        |
| ------------------------------------------------- | ------------------ | -------------------- |
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
| disk/impermanence                                 | nixos, homeManager | disk                 |
| disk/zfs-diff                                     | nixos              | disk                 |
| disk/zfs-disk-single                              | nixos              | disk                 |
| hardware/cpu-amd                                  | nixos              | hardware             |
| hardware/gpu-amd                                  | nixos              | hardware             |
| network/hosts                                     | nixos              | network              |
| network/network-boot                              | nixos              | network              |
| network/networking                                | nixos              | network              |
| network/openssh                                   | nixos              | network              |
| roles/nix-builder                                 |                    | roles                |
| roles/server                                      | nixos              | roles                |
| secrets/agenix                                    |                    | secrets              |
| services/acme                                     | nixos              | services             |
| services/media-data-share                         | nixos              | services             |
| services/nix-remote-build-server                  | nixos              | services             |
| services/prometheus-exporter                      | nixos              | services             |
| services/tailscale                                | nixos              | services             |
| services/tang                                     | nixos              | services             |
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

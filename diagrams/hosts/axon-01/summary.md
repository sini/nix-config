# Host: axon-01

## Overview

- **49** aspects across **2** classes (nixos, homeManager)
- **59** provider sub-aspects
- **8** policies fired
- **1** entity instances

## Aspects

| Aspect                           | Classes            | Parametric | Instance     |
| -------------------------------- | ------------------ | ---------- | ------------ |
| axon-01                          | nixos              | yes (host) | host:axon-01 |
| batteries/hostname/os            | nixos              | yes (host) | host:axon-01 |
| core/deterministic-uids          | nixos              | no         | host:axon-01 |
| core/facter                      | nixos              | no         | host:axon-01 |
| core/firewall-collector          | nixos              | no         | host:axon-01 |
| core/firmware                    | nixos              | no         | host:axon-01 |
| core/home-manager                | nixos              | no         | host:axon-01 |
| core/i18n                        | nixos              | no         | host:axon-01 |
| core/linux-kernel                | nixos              | no         | host:axon-01 |
| core/lix                         | nixos              | no         | host:axon-01 |
| core/nix                         | nixos              | no         | host:axon-01 |
| core/nix-remote-build-client     | nixos              | no         | host:axon-01 |
| core/persist-collector           | nixos              | no         | host:axon-01 |
| core/secrets-collector           | nixos              | no         | host:axon-01 |
| core/security                    | nixos              | no         | host:axon-01 |
| core/shell                       | nixos              | no         | host:axon-01 |
| core/ssd                         | nixos              | no         | host:axon-01 |
| core/stateVersion                | nixos              | no         | host:axon-01 |
| core/sudo                        | nixos              | no         | host:axon-01 |
| core/systemd                     | nixos              | no         | host:axon-01 |
| core/systemd-boot                | nixos              | no         | host:axon-01 |
| core/users                       | nixos              | no         | host:axon-01 |
| core/utils                       | nixos              | no         | host:axon-01 |
| disk/impermanence                | nixos, homeManager | no         | host:axon-01 |
| disk/xfs-disk-longhorn           | nixos              | no         | host:axon-01 |
| disk/zfs-diff                    | nixos              | no         | host:axon-01 |
| disk/zfs-disk-single             | nixos              | no         | host:axon-01 |
| hardware/cpu-amd                 | nixos              | no         | host:axon-01 |
| hardware/gpu-amd                 | nixos              | no         | host:axon-01 |
| hardware/thunderbolt-network     | nixos              | no         | host:axon-01 |
| insecure-predicate/os            | nixos              | yes (host) | host:axon-01 |
| network/hosts                    | nixos              | no         | host:axon-01 |
| network/network-boot             | nixos              | no         | host:axon-01 |
| network/networking               | nixos              | no         | host:axon-01 |
| network/openssh                  | nixos              | no         | host:axon-01 |
| roles/server                     | nixos              | no         | host:axon-01 |
| services/acme                    | nixos              | no         | host:axon-01 |
| services/bgp                     | nixos              | no         | host:axon-01 |
| services/cilium-bgp              | nixos              | no         | host:axon-01 |
| services/k3s                     | nixos              | no         | host:axon-01 |
| services/k3s-containerd          | nixos              | no         | host:axon-01 |
| services/media-data-share        | nixos              | no         | host:axon-01 |
| services/nix-remote-build-server | nixos              | no         | host:axon-01 |
| services/prometheus-exporter     | nixos              | no         | host:axon-01 |
| services/tailscale               | nixos              | no         | host:axon-01 |
| services/tang                    | nixos              | no         | host:axon-01 |
| services/thunderbolt-mesh-of     | nixos              | no         | host:axon-01 |
| unfree-predicate/os              | nixos              | yes (host) | host:axon-01 |
| zfs-disk-single/root             | nixos              | no         | host:axon-01 |

## Classes

### nixos (49)

- axon-01
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
- disk/impermanence
- disk/xfs-disk-longhorn
- disk/zfs-diff
- disk/zfs-disk-single
- hardware/cpu-amd
- hardware/gpu-amd
- hardware/thunderbolt-network
- insecure-predicate/os
- network/hosts
- network/network-boot
- network/networking
- network/openssh
- roles/server
- services/acme
- services/bgp
- services/cilium-bgp
- services/k3s
- services/k3s-containerd
- services/media-data-share
- services/nix-remote-build-server
- services/prometheus-exporter
- services/tailscale
- services/tang
- services/thunderbolt-mesh-of
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
| bgp/spoke                                         |                    | services/bgp         |
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
| disk/xfs-disk-longhorn                            | nixos              | disk                 |
| disk/zfs-diff                                     | nixos              | disk                 |
| disk/zfs-disk-single                              | nixos              | disk                 |
| hardware/cpu-amd                                  | nixos              | hardware             |
| hardware/gpu-amd                                  | nixos              | hardware             |
| hardware/thunderbolt-network                      | nixos              | hardware             |
| network/hosts                                     | nixos              | network              |
| network/network-boot                              | nixos              | network              |
| network/networking                                | nixos              | network              |
| network/openssh                                   | nixos              | network              |
| roles/nix-builder                                 |                    | roles                |
| roles/server                                      | nixos              | roles                |
| roles/unlock                                      |                    | roles                |
| secrets/agenix                                    |                    | secrets              |
| services/acme                                     | nixos              | services             |
| services/bgp                                      | nixos              | services             |
| services/cilium-bgp                               | nixos              | services             |
| services/k3s                                      | nixos              | services             |
| services/k3s-containerd                           | nixos              | services             |
| services/media-data-share                         | nixos              | services             |
| services/nix-remote-build-server                  | nixos              | services             |
| services/prometheus-exporter                      | nixos              | services             |
| services/tailscale                                | nixos              | services             |
| services/tang                                     | nixos              | services             |
| services/thunderbolt-mesh-of                      | nixos              | services             |
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

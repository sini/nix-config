# Host: uplink

## Overview

- **59** aspects across **2** classes (nixos, homeManager)
- **69** provider sub-aspects
- **8** policies fired
- **1** entity instances

## Aspects

| Aspect | Classes | Parametric | Instance |
| -------- | --------- | ------------ | ---------- |
| batteries/hostname/os | nixos | yes (host) | host:uplink |
| bgp/hub | nixos | no | host:uplink |
| core/deterministic-uids | nixos | no | host:uplink |
| core/facter | nixos | no | host:uplink |
| core/firewall-collector | nixos | no | host:uplink |
| core/firmware | nixos | no | host:uplink |
| core/home-manager | nixos | no | host:uplink |
| core/i18n | nixos | no | host:uplink |
| core/linux-kernel | nixos | no | host:uplink |
| core/lix | nixos | no | host:uplink |
| core/nix | nixos | no | host:uplink |
| core/nix-remote-build-client | nixos | no | host:uplink |
| core/persist-collector | nixos | no | host:uplink |
| core/secrets-collector | nixos | no | host:uplink |
| core/security | nixos | no | host:uplink |
| core/shell | nixos | no | host:uplink |
| core/ssd | nixos | no | host:uplink |
| core/stateVersion | nixos | no | host:uplink |
| core/sudo | nixos | no | host:uplink |
| core/systemd | nixos | no | host:uplink |
| core/systemd-boot | nixos | no | host:uplink |
| core/users | nixos | no | host:uplink |
| core/utils | nixos | no | host:uplink |
| disk/impermanence | nixos, homeManager | no | host:uplink |
| disk/zfs-diff | nixos | no | host:uplink |
| disk/zfs-disk-single | nixos | no | host:uplink |
| hardware/cpu-amd | nixos | no | host:uplink |
| hardware/gpu-intel | nixos | no | host:uplink |
| insecure-predicate/os | nixos | yes (host) | host:uplink |
| network/hosts | nixos | no | host:uplink |
| network/network-boot | nixos | no | host:uplink |
| network/networking | nixos | no | host:uplink |
| network/openssh | nixos | no | host:uplink |
| roles/server | nixos | no | host:uplink |
| services/acme | nixos | no | host:uplink |
| services/attic | nixos | no | host:uplink |
| services/bgp | nixos | no | host:uplink |
| services/den-docs-mirror | nixos | no | host:uplink |
| services/grafana | nixos | no | host:uplink |
| services/haproxy | nixos | no | host:uplink |
| services/headscale | nixos | no | host:uplink |
| services/homepage | nixos | no | host:uplink |
| services/jellyfin | nixos | no | host:uplink |
| services/kanidm | nixos | no | host:uplink |
| services/loki | nixos | no | host:uplink |
| services/media-data-share | nixos | no | host:uplink |
| services/nginx | nixos | no | host:uplink |
| services/nix-remote-build-server | nixos | no | host:uplink |
| services/oauth2-proxy | nixos | no | host:uplink |
| services/ollama | nixos | no | host:uplink |
| services/open-webui | nixos | no | host:uplink |
| services/prometheus | nixos | no | host:uplink |
| services/prometheus-exporter | nixos | no | host:uplink |
| services/tailscale | nixos | no | host:uplink |
| services/tang | nixos | no | host:uplink |
| unfree-predicate/os | nixos | yes (host) | host:uplink |
| uplink | nixos | yes (host) | host:uplink |
| virtualization/podman | nixos | no | host:uplink |
| zfs-disk-single/root | nixos | no | host:uplink |

## Classes

### nixos (59)

- batteries/hostname/os
- bgp/hub
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
- hardware/gpu-intel
- insecure-predicate/os
- network/hosts
- network/network-boot
- network/networking
- network/openssh
- roles/server
- services/acme
- services/attic
- services/bgp
- services/den-docs-mirror
- services/grafana
- services/haproxy
- services/headscale
- services/homepage
- services/jellyfin
- services/kanidm
- services/loki
- services/media-data-share
- services/nginx
- services/nix-remote-build-server
- services/oauth2-proxy
- services/ollama
- services/open-webui
- services/prometheus
- services/prometheus-exporter
- services/tailscale
- services/tang
- unfree-predicate/os
- uplink
- virtualization/podman
- zfs-disk-single/root


### homeManager (1)

- disk/impermanence


## Providers

| Provider Aspect | Classes | Provider Path |
| ----------------- | --------- | --------------- |
| apps/zsh | homeManager | apps |
| batteries/define-user |  | den/batteries |
| batteries/host/resolve(define-user):den/batteries |  | den/batteries |
| batteries/hostname |  | den/batteries |
| batteries/hostname/os | nixos | den/batteries |
| batteries/primary-user |  | den/batteries |
| bgp/hub | nixos | services/bgp |
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
| disk/impermanence | nixos, homeManager | disk |
| disk/zfs-diff | nixos | disk |
| disk/zfs-disk-single | nixos | disk |
| hardware/cpu-amd | nixos | hardware |
| hardware/gpu-intel | nixos | hardware |
| network/hosts | nixos | network |
| network/network-boot | nixos | network |
| network/networking | nixos | network |
| network/openssh | nixos | network |
| roles/metrics-ingester |  | roles |
| roles/nix-builder |  | roles |
| roles/server | nixos | roles |
| roles/unlock |  | roles |
| secrets/agenix |  | secrets |
| services/acme | nixos | services |
| services/attic | nixos | services |
| services/bgp | nixos | services |
| services/den-docs-mirror | nixos | services |
| services/grafana | nixos | services |
| services/haproxy | nixos | services |
| services/headscale | nixos | services |
| services/homepage | nixos | services |
| services/jellyfin | nixos | services |
| services/kanidm | nixos | services |
| services/loki | nixos | services |
| services/media-data-share | nixos | services |
| services/nginx | nixos | services |
| services/nix-remote-build-server | nixos | services |
| services/oauth2-proxy | nixos | services |
| services/ollama | nixos | services |
| services/open-webui | nixos | services |
| services/prometheus | nixos | services |
| services/prometheus-exporter | nixos | services |
| services/tailscale | nixos | services |
| services/tang | nixos | services |
| virtualization/podman | nixos | virtualization |
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
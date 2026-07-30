# Host: slab

## Overview

- **39** aspects across **1** classes (nixos)
- **69** provider sub-aspects
- **27** policies fired
- **2** entity instances

## Aspects

| Aspect | Classes | Parametric | Instance |
| -------- | --------- | ------------ | ---------- |
| agenix-identity/sini@axon-01 | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@axon-02 | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@axon-03 | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@bitstream | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@blade | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@cortex | nixos | yes (host, secretsConfig, user) | user:sini |
| agenix-identity/sini@uplink | nixos | yes (host, secretsConfig, user) | user:sini |
| batteries/define-user/sini@slab | nixos | yes (host, user) | host:slab |
| batteries/primary-user(sini@axon-01) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@axon-02) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@axon-03) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@bitstream) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@blade) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@cortex) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@patch) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@slab) | nixos | yes (host, user) | user:sini |
| batteries/primary-user(sini@uplink) | nixos | yes (host, user) | user:sini |
| hardware/adb | nixos | no | host:slab |
| network/firewall-collector | nixos | no | host:slab |
| opkssh-authz/sini@axon-01 | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@axon-02 | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@axon-03 | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@bitstream | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@blade | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@cortex | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@patch | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@slab | nixos | yes (host, user) | user:sini |
| opkssh-authz/sini@uplink | nixos | yes (host, user) | user:sini |
| secrets/collector | nixos | no | host:slab |
| syncthing/peer | nixos | no | user:sini |
| user-enrich/sini@axon-01 | nixos | yes (host, user) | user:sini |
| user-enrich/sini@axon-02 | nixos | yes (host, user) | user:sini |
| user-enrich/sini@axon-03 | nixos | yes (host, user) | user:sini |
| user-enrich/sini@bitstream | nixos | yes (host, user) | user:sini |
| user-enrich/sini@blade | nixos | yes (host, user) | user:sini |
| user-enrich/sini@cortex | nixos | yes (host, user) | user:sini |
| user-enrich/sini@patch | nixos | yes (host, user) | user:sini |
| user-enrich/sini@slab | nixos | yes (host, user) | user:sini |
| user-enrich/sini@uplink | nixos | yes (host, user) | user:sini |

## Classes

### nixos (39)

- agenix-identity/sini@axon-01
- agenix-identity/sini@axon-02
- agenix-identity/sini@axon-03
- agenix-identity/sini@bitstream
- agenix-identity/sini@blade
- agenix-identity/sini@cortex
- agenix-identity/sini@uplink
- batteries/define-user/sini@slab
- batteries/primary-user(sini@axon-01)
- batteries/primary-user(sini@axon-02)
- batteries/primary-user(sini@axon-03)
- batteries/primary-user(sini@bitstream)
- batteries/primary-user(sini@blade)
- batteries/primary-user(sini@cortex)
- batteries/primary-user(sini@patch)
- batteries/primary-user(sini@slab)
- batteries/primary-user(sini@uplink)
- hardware/adb
- network/firewall-collector
- opkssh-authz/sini@axon-01
- opkssh-authz/sini@axon-02
- opkssh-authz/sini@axon-03
- opkssh-authz/sini@bitstream
- opkssh-authz/sini@blade
- opkssh-authz/sini@cortex
- opkssh-authz/sini@patch
- opkssh-authz/sini@slab
- opkssh-authz/sini@uplink
- secrets/collector
- syncthing/peer
- user-enrich/sini@axon-01
- user-enrich/sini@axon-02
- user-enrich/sini@axon-03
- user-enrich/sini@bitstream
- user-enrich/sini@blade
- user-enrich/sini@cortex
- user-enrich/sini@patch
- user-enrich/sini@slab
- user-enrich/sini@uplink


## Providers

| Provider Aspect | Classes | Provider Path |
| ----------------- | --------- | --------------- |
| ai/beads |  | applications/dev/ai |
| ai/claude |  | applications/dev/ai |
| ai/hunk |  | applications/dev/ai |
| ai/llm-agents |  | applications/dev/ai |
| ai/rtk |  | applications/dev/ai |
| batteries/define-user |  | den/batteries |
| batteries/define-user/sini@slab | nixos | den/batteries |
| batteries/host-aspects |  | den/batteries |
| batteries/hostname |  | den/batteries |
| batteries/hostname/os |  | den/batteries |
| batteries/inputs' |  | den/batteries |
| batteries/inputs'/os |  | den/batteries |
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
| batteries/self'/os |  | den/batteries |
| batteries/self'/user |  | den/batteries |
| core/nix-on-droid-base |  | core |
| dev/git |  | applications/dev |
| editor/nvf |  | applications/dev/editor |
| git/delta |  | applications/dev/git |
| git/github |  | applications/dev/git |
| git/jujutsu |  | applications/dev/git |
| git/lazygit |  | applications/dev/git |
| git/mergiraf |  | applications/dev/git |
| hardware/adb | nixos | hardware |
| k8s/k9s |  | applications/dev/k8s |
| lang/go |  | applications/dev/lang |
| lang/nix |  | applications/dev/lang |
| lang/python |  | applications/dev/lang |
| lang/rust |  | applications/dev/lang |
| mcp/codebase-memory |  | applications/dev/ai/mcp |
| media/spotify-player |  | applications/media |
| mux/herdr |  | applications/dev/mux |
| mux/sesh |  | applications/dev/mux |
| mux/tmux |  | applications/dev/mux |
| mux/zellij |  | applications/dev/mux |
| network/firewall-collector | nixos | core/network |
| roles/dev |  | roles |
| secrets/collector | nixos | core/secrets |
| security/bitwarden |  | applications/dev/security |
| security/signing-key |  | applications/dev/security |
| security/ssh |  | applications/dev/security |
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
| shell/zsh |  | applications/shell |
| syncthing/peer | nixos | core/network/syncthing |
| users/resolved-user-emitter |  | core/users |

## Policies

- **broadcast-syncthing-hub-shares** (from: user)
- **broadcast-syncthing-peers** (from: user)
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
- **drop-user-to-host-on-droid** (from: host)
- **drop-user-to-host-on-droid** (from: user)
- **env-users** (from: host)
- **expose-resolved-users** (from: user)
- **hm-user-detect** (from: user)
- **homeAarch64-to-hm** (from: user)
- **homeDarwin-to-hm** (from: user)
- **homeLinux-to-hm** (from: user)
- **host-aspects-project** (from: user)
- **host-modules-capture** (from: host)
- **host-to-droidHm-users** (from: host)
- **os-to-host** (from: user)
- **primary-user-for-owner** (from: user)
- **user-aspect-auto-include** (from: user)
- **user-to-host** (from: user)

## Pipe Data

**Produces:** none
**Collects:** none
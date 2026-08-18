# Host: patch

## Overview

- **68** aspects across **1** classes (nixos)
- **135** provider sub-aspects
- **27** policies fired
- **2** entity instances

## Aspects

| Aspect                                 | Classes | Parametric                      | Instance   |
| -------------------------------------- | ------- | ------------------------------- | ---------- |
| agenix-identity/sini@axon-01           | nixos   | yes (host, secretsConfig, user) | user:sini  |
| agenix-identity/sini@axon-02           | nixos   | yes (host, secretsConfig, user) | user:sini  |
| agenix-identity/sini@axon-03           | nixos   | yes (host, secretsConfig, user) | user:sini  |
| agenix-identity/sini@bitstream         | nixos   | yes (host, secretsConfig, user) | user:sini  |
| agenix-identity/sini@blade             | nixos   | yes (host, secretsConfig, user) | user:sini  |
| agenix-identity/sini@cortex            | nixos   | yes (host, secretsConfig, user) | user:sini  |
| agenix-identity/sini@uplink            | nixos   | yes (host, secretsConfig, user) | user:sini  |
| batteries/define-user/sini@patch       | nixos   | yes (host, user)                | host:patch |
| batteries/primary-user(sini@axon-01)   | nixos   | yes (host, user)                | user:sini  |
| batteries/primary-user(sini@axon-02)   | nixos   | yes (host, user)                | user:sini  |
| batteries/primary-user(sini@axon-03)   | nixos   | yes (host, user)                | user:sini  |
| batteries/primary-user(sini@bitstream) | nixos   | yes (host, user)                | user:sini  |
| batteries/primary-user(sini@blade)     | nixos   | yes (host, user)                | user:sini  |
| batteries/primary-user(sini@cortex)    | nixos   | yes (host, user)                | user:sini  |
| batteries/primary-user(sini@patch)     | nixos   | yes (host, user)                | user:sini  |
| batteries/primary-user(sini@slab)      | nixos   | yes (host, user)                | user:sini  |
| batteries/primary-user(sini@uplink)    | nixos   | yes (host, user)                | user:sini  |
| core/impermanence                      | nixos   | no                              | host:patch |
| core/nix                               | nixos   | no                              | host:patch |
| core/security                          | nixos   | no                              | host:patch |
| core/systemd                           | nixos   | no                              | host:patch |
| core/users                             | nixos   | no                              | host:patch |
| core/utils                             | nixos   | no                              | host:patch |
| hardware/adb                           | nixos   | no                              | host:patch |
| host/resolve(darwin-workstation)       | nixos   | no                              | host:patch |
| impermanence/btrfs                     | nixos   | no                              | host:patch |
| impermanence/persist-collector         | nixos   | no                              | host:patch |
| impermanence/zfs                       | nixos   | no                              | host:patch |
| localization/i18n                      | nixos   | no                              | host:patch |
| network/firewall-collector             | nixos   | no                              | host:patch |
| network/hostsfile                      | nixos   | no                              | host:patch |
| network/networking                     | nixos   | no                              | host:patch |
| network/tailscale                      | nixos   | no                              | host:patch |
| nix/stateVersion                       | nixos   | no                              | host:patch |
| opkssh-authz/sini@axon-01              | nixos   | yes (host, user)                | user:sini  |
| opkssh-authz/sini@axon-02              | nixos   | yes (host, user)                | user:sini  |
| opkssh-authz/sini@axon-03              | nixos   | yes (host, user)                | user:sini  |
| opkssh-authz/sini@bitstream            | nixos   | yes (host, user)                | user:sini  |
| opkssh-authz/sini@blade                | nixos   | yes (host, user)                | user:sini  |
| opkssh-authz/sini@cortex               | nixos   | yes (host, user)                | user:sini  |
| opkssh-authz/sini@patch                | nixos   | yes (host, user)                | user:sini  |
| opkssh-authz/sini@slab                 | nixos   | yes (host, user)                | user:sini  |
| opkssh-authz/sini@uplink               | nixos   | yes (host, user)                | user:sini  |
| perf/disable-docs                      | nixos   | no                              | host:patch |
| perf/ssd                               | nixos   | no                              | host:patch |
| perf/zram-swap                         | nixos   | no                              | host:patch |
| secrets/collector                      | nixos   | no                              | host:patch |
| security/openssh                       | nixos   | no                              | host:patch |
| security/opkssh                        | nixos   | no                              | host:patch |
| security/sudo                          | nixos   | no                              | host:patch |
| style/stylix                           | nixos   | no                              | host:patch |
| syncthing/peer                         | nixos   | no                              | user:sini  |
| system/facter                          | nixos   | no                              | host:patch |
| system/firmware                        | nixos   | no                              | host:patch |
| system/linux-kernel                    | nixos   | no                              | host:patch |
| systemd/boot                           | nixos   | no                              | host:patch |
| user-enrich/sini@axon-01               | nixos   | yes (host, user)                | user:sini  |
| user-enrich/sini@axon-02               | nixos   | yes (host, user)                | user:sini  |
| user-enrich/sini@axon-03               | nixos   | yes (host, user)                | user:sini  |
| user-enrich/sini@bitstream             | nixos   | yes (host, user)                | user:sini  |
| user-enrich/sini@blade                 | nixos   | yes (host, user)                | user:sini  |
| user-enrich/sini@cortex                | nixos   | yes (host, user)                | user:sini  |
| user-enrich/sini@patch                 | nixos   | yes (host, user)                | user:sini  |
| user-enrich/sini@slab                  | nixos   | yes (host, user)                | user:sini  |
| user-enrich/sini@uplink                | nixos   | yes (host, user)                | user:sini  |
| users/deterministic-uids               | nixos   | no                              | host:patch |
| users/home-manager-shared              | nixos   | no                              | host:patch |
| users/shell                            | nixos   | no                              | host:patch |

## Classes

### nixos (68)

- agenix-identity/sini@axon-01
- agenix-identity/sini@axon-02
- agenix-identity/sini@axon-03
- agenix-identity/sini@bitstream
- agenix-identity/sini@blade
- agenix-identity/sini@cortex
- agenix-identity/sini@uplink
- batteries/define-user/sini@patch
- batteries/primary-user(sini@axon-01)
- batteries/primary-user(sini@axon-02)
- batteries/primary-user(sini@axon-03)
- batteries/primary-user(sini@bitstream)
- batteries/primary-user(sini@blade)
- batteries/primary-user(sini@cortex)
- batteries/primary-user(sini@patch)
- batteries/primary-user(sini@slab)
- batteries/primary-user(sini@uplink)
- core/impermanence
- core/nix
- core/security
- core/systemd
- core/users
- core/utils
- hardware/adb
- host/resolve(darwin-workstation)
- impermanence/btrfs
- impermanence/persist-collector
- impermanence/zfs
- localization/i18n
- network/firewall-collector
- network/hostsfile
- network/networking
- network/tailscale
- nix/stateVersion
- opkssh-authz/sini@axon-01
- opkssh-authz/sini@axon-02
- opkssh-authz/sini@axon-03
- opkssh-authz/sini@bitstream
- opkssh-authz/sini@blade
- opkssh-authz/sini@cortex
- opkssh-authz/sini@patch
- opkssh-authz/sini@slab
- opkssh-authz/sini@uplink
- perf/disable-docs
- perf/ssd
- perf/zram-swap
- secrets/collector
- security/openssh
- security/opkssh
- security/sudo
- style/stylix
- syncthing/peer
- system/facter
- system/firmware
- system/linux-kernel
- systemd/boot
- user-enrich/sini@axon-01
- user-enrich/sini@axon-02
- user-enrich/sini@axon-03
- user-enrich/sini@bitstream
- user-enrich/sini@blade
- user-enrich/sini@cortex
- user-enrich/sini@patch
- user-enrich/sini@slab
- user-enrich/sini@uplink
- users/deterministic-uids
- users/home-manager-shared
- users/shell

## Providers

| Provider Aspect                        | Classes | Provider Path                  |
| -------------------------------------- | ------- | ------------------------------ |
| ai/beads                               |         | applications/dev/ai            |
| ai/claude                              |         | applications/dev/ai            |
| ai/hunk                                |         | applications/dev/ai            |
| ai/llm-agents                          |         | applications/dev/ai            |
| ai/rtk                                 |         | applications/dev/ai            |
| applications/karabiner                 |         | macos/applications             |
| applications/raycast                   |         | macos/applications             |
| batteries/define-user                  |         | den/batteries                  |
| batteries/define-user/sini@patch       | nixos   | den/batteries                  |
| batteries/host-aspects                 |         | den/batteries                  |
| batteries/hostname                     |         | den/batteries                  |
| batteries/hostname/os                  |         | den/batteries                  |
| batteries/inputs'                      |         | den/batteries                  |
| batteries/inputs'/os                   |         | den/batteries                  |
| batteries/inputs'/user                 |         | den/batteries                  |
| batteries/primary-user(sini@axon-01)   | nixos   | den/batteries                  |
| batteries/primary-user(sini@axon-02)   | nixos   | den/batteries                  |
| batteries/primary-user(sini@axon-03)   | nixos   | den/batteries                  |
| batteries/primary-user(sini@bitstream) | nixos   | den/batteries                  |
| batteries/primary-user(sini@blade)     | nixos   | den/batteries                  |
| batteries/primary-user(sini@cortex)    | nixos   | den/batteries                  |
| batteries/primary-user(sini@patch)     | nixos   | den/batteries                  |
| batteries/primary-user(sini@slab)      | nixos   | den/batteries                  |
| batteries/primary-user(sini@uplink)    | nixos   | den/batteries                  |
| batteries/self'                        |         | den/batteries                  |
| batteries/self'/os                     |         | den/batteries                  |
| batteries/self'/user                   |         | den/batteries                  |
| browsers/chromium                      |         | applications/browsers          |
| browsers/firefox                       |         | applications/browsers          |
| codium/core                            |         | applications/dev/editor/codium |
| codium/vscode                          |         | applications/dev/editor/codium |
| core/impermanence                      | nixos   | core                           |
| core/nix                               | nixos   | core                           |
| core/security                          | nixos   | core                           |
| core/systemd                           | nixos   | core                           |
| core/users                             | nixos   | core                           |
| core/utils                             | nixos   | core                           |
| defaults/appearance                    |         | macos/defaults                 |
| defaults/dock                          |         | macos/defaults                 |
| defaults/finder                        |         | macos/defaults                 |
| defaults/keybindings                   |         | macos/defaults                 |
| defaults/keyboard                      |         | macos/defaults                 |
| defaults/screencapture                 |         | macos/defaults                 |
| defaults/security                      |         | macos/defaults                 |
| defaults/trackpad                      |         | macos/defaults                 |
| dev/git                                |         | applications/dev               |
| editor/nvf                             |         | applications/dev/editor        |
| git/delta                              |         | applications/dev/git           |
| git/github                             |         | applications/dev/git           |
| git/gitkraken                          |         | applications/dev/git           |
| git/jujutsu                            |         | applications/dev/git           |
| git/lazygit                            |         | applications/dev/git           |
| git/mergiraf                           |         | applications/dev/git           |
| hardware/adb                           | nixos   | hardware                       |
| impermanence/btrfs                     | nixos   | core/impermanence              |
| impermanence/persist-collector         | nixos   | core/impermanence              |
| impermanence/persist-home-collector    |         | core/impermanence              |
| impermanence/zfs                       | nixos   | core/impermanence              |
| k8s/k9s                                |         | applications/dev/k8s           |
| lang/c                                 |         | applications/dev/lang          |
| lang/go                                |         | applications/dev/lang          |
| lang/lua                               |         | applications/dev/lang          |
| lang/markdown                          |         | applications/dev/lang          |
| lang/nix                               |         | applications/dev/lang          |
| lang/python                            |         | applications/dev/lang          |
| lang/rust                              |         | applications/dev/lang          |
| lang/shell                             |         | applications/dev/lang          |
| localization/i18n                      | nixos   | core/localization              |
| localization/time                      |         | core/localization              |
| macos/fonts                            |         | macos                          |
| macos/homebrew                         |         | macos                          |
| macos/spotlight-apps                   |         | macos                          |
| mail/protonmail                        |         | applications/mail              |
| mcp/codebase-memory                    |         | applications/dev/ai/mcp        |
| media/spotify-player                   |         | applications/media             |
| mux/herdr                              |         | applications/dev/mux           |
| mux/sesh                               |         | applications/dev/mux           |
| mux/tmux                               |         | applications/dev/mux           |
| mux/zellij                             |         | applications/dev/mux           |
| network/firewall-collector             | nixos   | core/network                   |
| network/hostsfile                      | nixos   | core/network                   |
| network/networking                     | nixos   | core/network                   |
| network/tailscale                      | nixos   | core/network                   |
| nix/linux-builder                      |         | core/nix                       |
| nix/nixpkgs                            |         | core/nix                       |
| nix/stateVersion                       | nixos   | core/nix                       |
| perf/disable-docs                      | nixos   | core/perf                      |
| perf/ssd                               | nixos   | core/perf                      |
| perf/zram-swap                         | nixos   | core/perf                      |
| productivity/obs-studio                |         | applications/productivity      |
| productivity/obsidian                  |         | applications/productivity      |
| roles/darwin-workstation               |         | roles                          |
| roles/default                          |         | roles                          |
| roles/dev                              |         | roles                          |
| secrets/agenix                         |         | secrets                        |
| secrets/collector                      | nixos   | core/secrets                   |
| security/bitwarden                     |         | applications/dev/security      |
| security/openssh                       | nixos   | core/security                  |
| security/opkssh                        | nixos   | core/security                  |
| security/opkssh-client                 |         | applications/dev/security      |
| security/signing-key                   |         | applications/dev/security      |
| security/ssh                           |         | applications/dev/security      |
| security/ssh-agent-mux                 |         | applications/dev/security      |
| security/sudo                          | nixos   | core/security                  |
| shell/archive                          |         | applications/shell             |
| shell/bat                              |         | applications/dev/shell         |
| shell/bottom                           |         | applications/dev/shell         |
| shell/btop                             |         | applications/dev/shell         |
| shell/data                             |         | applications/shell             |
| shell/direnv                           |         | applications/dev/shell         |
| shell/disk                             |         | applications/shell             |
| shell/eza                              |         | applications/dev/shell         |
| shell/nix-index                        |         | applications/shell             |
| shell/process                          |         | applications/shell             |
| shell/search                           |         | applications/shell             |
| shell/starship                         |         | applications/dev/shell         |
| shell/yazi                             |         | applications/shell             |
| shell/zoxide                           |         | applications/shell             |
| shell/zsh                              |         | applications/shell             |
| style/stylix                           | nixos   | desktop/style                  |
| syncthing/member                       |         | core/network/syncthing         |
| syncthing/peer                         | nixos   | core/network/syncthing         |
| system/facter                          | nixos   | core/system                    |
| system/firmware                        | nixos   | core/system                    |
| system/linux-kernel                    | nixos   | core/system                    |
| systemd/boot                           | nixos   | core/systemd                   |
| terminals/alacritty                    |         | applications/terminals         |
| terminals/kitty                        |         | applications/terminals         |
| users/deterministic-uids               | nixos   | core/users                     |
| users/home-manager-shared              | nixos   | core/users                     |
| users/resolved-user-emitter            |         | core/users                     |
| users/shell                            | nixos   | core/users                     |
| wm/aerospace                           |         | macos/wm                       |
| wm/jankyborders                        |         | macos/wm                       |
| wm/sketchybar                          |         | macos/wm                       |

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
- **drop-user-to-host-on-droid** (from: user)
- **env-users** (from: host)
- **expose-resolved-users** (from: user)
- **hm-user-detect** (from: user)
- **homeAarch64-to-hm** (from: user)
- **homeDarwin-to-hm** (from: user)
- **homeLinux-to-hm** (from: user)
- **host-aspects-project** (from: user)
- **host-modules-capture** (from: host)
- **host-to-hm-users** (from: host)
- **os-to-host** (from: host)
- **os-to-host** (from: user)
- **primary-user-for-owner** (from: user)
- **user-aspect-auto-include** (from: user)
- **user-to-host** (from: user)

## Pipe Data

**Produces:** none **Collects:** none

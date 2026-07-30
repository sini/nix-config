# Scope Sequence: patch

![Scope sequence](./scope-seq.mmd.svg)

```mermaid
%%{init: {"theme":"base","themeVariables":{"activationBkgColor":"#313244","activationBorderColor":"#6c7086","actorBkg":"#313244","actorBorder":"#a6adc8","actorLineColor":"#a6adc8","actorTextColor":"#cdd6f4","background":"#1e1e2e","classText":"#cdd6f4","clusterBkg":"#313244","clusterBorder":"#6c7086","edgeLabelBackground":"#1e1e2e","labelBoxBkgColor":"#313244","labelBoxBorderColor":"#a6adc8","labelTextColor":"#cdd6f4","lineColor":"#a6adc8","loopTextColor":"#cdd6f4","mainBkg":"#313244","nodeBkg":"#313244","nodeBorder":"#a6adc8","nodeTextColor":"#cdd6f4","noteBkgColor":"#313244","noteBorderColor":"#6c7086","noteTextColor":"#cdd6f4","pie1":"#f38ba8","pie2":"#fab387","pie3":"#f9e2af","pie4":"#a6e3a1","pie5":"#94e2d5","pie6":"#89b4fa","pie7":"#cba6f7","pie8":"#f2cdcd","pieLegendTextColor":"#cdd6f4","pieOuterStrokeColor":"#6c7086","pieSectionTextColor":"#cdd6f4","pieStrokeColor":"#6c7086","pieTitleTextColor":"#cdd6f4","primaryBorderColor":"#a6adc8","primaryColor":"#313244","primaryTextColor":"#cdd6f4","secondBkg":"#313244","secondaryBorderColor":"#6c7086","secondaryColor":"#313244","secondaryTextColor":"#cdd6f4","sequenceNumberColor":"#1e1e2e","signalColor":"#a6adc8","signalTextColor":"#cdd6f4","tertiaryBorderColor":"#6c7086","tertiaryColor":"#313244","tertiaryTextColor":"#cdd6f4","textColor":"#cdd6f4","titleColor":"#cdd6f4"}}}%%
sequenceDiagram
    participant host as host { accessGroups, environment, fleet, host, secretsConfig }
    participant user as user { accessGroups, environment, fleet, host, secretsConfig, user }


    activate host
    host ->> host: agenix/patch(host, secretsConfig)
    host ->> host: security/bitwarden(user)
    host ->> host: batteries/define-user/sini@patch(host, user)
    host ->> host: dev/git(user)
    host ->> host: git/gitkraken(user)
    host ->> host: batteries/hostname/os(host)
    host ->> host: batteries/inputs'/os(host)
    host ->> host: batteries/inputs'/user(host, user)
    host ->> host: insecure-predicate/os(host)
    host ->> host: insecure-predicate/user(host, user)
    host ->> host: git/jujutsu(user)
    host ->> host: syncthing/member(user)
    host ->> host: patch(host)
    host ->> host: batteries/self'/os(host)
    host ->> host: batteries/self'/user(host, user)
    host ->> host: security/signing-key(user)
    host ->> host: security/ssh(user)
    host ->> host: unfree-predicate/os(host)
    host ->> host: unfree-predicate/user(host, user)
    deactivate host
    Note over host: hardware/adb, wm/aerospace, secrets/agenix, terminals/alacritty<br/>defaults/appearance, shell/archive, shell/bat, ai/beads<br/>systemd/boot, shell/bottom, shell/btop, impermanence/btrfs<br/>lang/c, browsers/chromium, ai/claude, mcp/codebase-memory<br/>secrets/collector, codium/core, roles/darwin-workstation, shell/data<br/>roles/default, default, batteries/define-user, git/delta<br/>users/deterministic-uids, roles/dev, shell/direnv, perf/disable-docs<br/>shell/disk, defaults/dock, shell/eza, system/facter<br/>defaults/finder, browsers/firefox, network/firewall-collector, system/firmware<br/>macos/fonts, git/github, lang/go, mux/herdr<br/>users/home-manager-shared, macos/homebrew, host, host/resolve(darwin-workstation)<br/>host/resolve(host), host/resolve(user), batteries/hostname, network/hostsfile<br/>ai/hunk, localization/i18n, core/impermanence, batteries/inputs'<br/>insecure-predicate, wm/jankyborders, k8s/k9s, applications/karabiner<br/>defaults/keybindings, defaults/keyboard, terminals/kitty, git/lazygit<br/>nix/linux-builder, system/linux-kernel, ai/llm-agents, lang/lua<br/>lang/markdown, git/mergiraf, network/networking, core/nix<br/>lang/nix, shell/nix-index, nix/nixpkgs, editor/nvf<br/>productivity/obs-studio, productivity/obsidian, security/openssh, security/opkssh<br/>security/opkssh-client, impermanence/persist-collector, impermanence/persist-home-collector, shell/process<br/>mail/protonmail, lang/python, applications/raycast, ai/rtk<br/>lang/rust, defaults/screencapture, shell/search, core/security<br/>defaults/security, batteries/self', mux/sesh, users/shell<br/>lang/shell, wm/sketchybar, macos/spotlight-apps, perf/ssd<br/>security/ssh-agent-mux, shell/starship, nix/stateVersion, style/stylix<br/>security/sudo, core/systemd, network/tailscale, localization/time<br/>mux/tmux, defaults/trackpad, unfree-predicate, core/users<br/>core/utils, codium/vscode, shell/yazi, mux/zellij<br/>impermanence/zfs, shell/zoxide, perf/zram-swap, shell/zsh

    activate user
    user ->> user: agenix-identity/sini@axon-01(host, secretsConfig, user)
    user ->> user: agenix-identity/sini@axon-02(host, secretsConfig, user)
    user ->> user: agenix-identity/sini@axon-03(host, secretsConfig, user)
    user ->> user: agenix-identity/sini@bitstream(host, secretsConfig, user)
    user ->> user: agenix-identity/sini@blade(host, secretsConfig, user)
    user ->> user: agenix-identity/sini@cortex(host, secretsConfig, user)
    user ->> user: agenix-identity/sini@patch(host, secretsConfig, user)
    user ->> user: agenix-identity/sini@slab(host, secretsConfig, user)
    user ->> user: agenix-identity/sini@uplink(host, secretsConfig, user)
    user ->> user: opkssh-authz/sini@axon-01(host, user)
    user ->> user: opkssh-authz/sini@axon-02(host, user)
    user ->> user: opkssh-authz/sini@axon-03(host, user)
    user ->> user: opkssh-authz/sini@bitstream(host, user)
    user ->> user: opkssh-authz/sini@blade(host, user)
    user ->> user: opkssh-authz/sini@cortex(host, user)
    user ->> user: opkssh-authz/sini@patch(host, user)
    user ->> user: opkssh-authz/sini@slab(host, user)
    user ->> user: opkssh-authz/sini@uplink(host, user)
    user ->> user: batteries/primary-user(sini@axon-01)(host, user)
    user ->> user: batteries/primary-user(sini@axon-02)(host, user)
    user ->> user: batteries/primary-user(sini@axon-03)(host, user)
    user ->> user: batteries/primary-user(sini@bitstream)(host, user)
    user ->> user: batteries/primary-user(sini@blade)(host, user)
    user ->> user: batteries/primary-user(sini@cortex)(host, user)
    user ->> user: batteries/primary-user(sini@patch)(host, user)
    user ->> user: batteries/primary-user(sini@slab)(host, user)
    user ->> user: batteries/primary-user(sini@uplink)(host, user)
    user ->> user: sini(user)
    user ->> user: user-enrich/sini@axon-01(host, user)
    user ->> user: user-enrich/sini@axon-02(host, user)
    user ->> user: user-enrich/sini@axon-03(host, user)
    user ->> user: user-enrich/sini@bitstream(host, user)
    user ->> user: user-enrich/sini@blade(host, user)
    user ->> user: user-enrich/sini@cortex(host, user)
    user ->> user: user-enrich/sini@patch(host, user)
    user ->> user: user-enrich/sini@slab(host, user)
    user ->> user: user-enrich/sini@uplink(host, user)
    deactivate user
    Note over user: <policy:droidHm-user-detect>[0], <policy:hm-user-detect>[0], <policy:user-aspect-auto-include>[3], default<br/>batteries/host-aspects, syncthing/peer, users/resolved-user-emitter, media/spotify-player<br/>user, user/resolve(user)
```

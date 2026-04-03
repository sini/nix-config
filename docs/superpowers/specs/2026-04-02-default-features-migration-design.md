# Default Features Migration Design

## Overview

Migrate all 30 features required by `features.default` to den aspects, achieving
1:1 parity with the current feature system. This extends the den migration
established in `2026-04-02-den-migration-design.md`.

## Scope

29 features to migrate (zsh already done as `den.aspects.shell`):

| Feature            | Source                             | Complexity | Batch |
| ------------------ | ---------------------------------- | ---------- | ----- |
| avahi              | core/network/avahi.nix             | trivial    | 1     |
| disko              | core/disko/disko.nix               | trivial    | 1     |
| facter             | core/facter/facter.nix             | trivial    | 1     |
| i18n               | core/i18n/i18n.nix                 | trivial    | 1     |
| power-mgmt         | core/power-mgmt/default.nix        | trivial    | 1     |
| shell              | core/shell/zsh.nix                 | trivial    | 1     |
| ssd                | core/ssd/default.nix               | trivial    | 1     |
| stateVersion       | core/nix/stateVersion.nix          | trivial    | 1     |
| time               | core/time/time.nix                 | trivial    | 1     |
| firmware           | core/firmware/default.nix          | simple     | 1     |
| home-manager       | core/home-manager/default.nix      | simple     | 1     |
| hosts              | core/network/hosts.nix             | simple     | 1     |
| linux-kernel       | core/linux-kernel.nix              | simple     | 1     |
| nixpkgs            | core/nix/nixpkgs/                  | simple     | 1     |
| openssh            | core/openssh/openssh.nix           | simple     | 1     |
| security           | core/security/                     | simple     | 1     |
| sudo               | core/sudo/sudo-rs.nix              | simple     | 1     |
| systemd            | core/systemd/default.nix           | simple     | 1     |
| systemd-boot       | core/boot/systemd-boot.nix         | simple     | 1     |
| utils              | core/utils/utils.nix               | simple     | 1     |
| deterministic-uids | core/deterministic-uids/           | moderate   | 2     |
| nix                | core/nix/nix.nix                   | moderate   | 2     |
| tailscale          | core/network/tailscale.nix         | moderate   | 2     |
| users              | core/users/default.nix             | moderate   | 2     |
| agenix             | core/agenix/agenix.nix             | complex    | 3     |
| impermanence       | core/impermanence/impermanence.nix | complex    | 3     |
| networking         | core/network/networking.nix        | complex    | 3     |

## Migration Patterns

### Direct Translation (trivial/simple)

```
feature.linux    → den.lib.perHost { nixos = ...; }
feature.darwin   → den.lib.perHost { darwin = ...; }
feature.os       → den.lib.perHost { os = ...; }
feature.system   → den.lib.perHost { os = ...; }
feature.home     → den.lib.perUser { homeManager = ...; }
feature.homeLinux → den.lib.perUser { homeLinux = ...; }
```

### Features with `provides` (firmware, security, systemd, tailscale)

Providers become sub-aspects:

```nix
den.aspects.firmware = {
  includes = lib.attrValues den.aspects.firmware._;
  _ = {
    config = den.lib.perHost { nixos = ...; };
    impermanence = den.lib.perHost { nixos = ...; };  # was provides.impermanence
  };
};
```

### Features with `settings` (linux-kernel, deterministic-uids, tailscale)

For now, settings are inlined as config read from the host schema. Full settings
layering migration is deferred per the main design spec.

### Features with `collectsProviders` (agenix, impermanence, networking)

These use custom forwarding classes following gwenodai's persist pattern:

```nix
# Example: networking collects firewall rules from active aspects
firewall-class = { class, aspect-chain }: den._.forward {
  each = lib.optional (class == "nixos") true;
  fromClass = _: "firewall";
  intoClass = _: "nixos";
  intoPath = _: [ "networking" "firewall" ];
  fromAspect = _: lib.head aspect-chain;
};
```

Each aspect that currently `provides.firewall` instead declares a `firewall`
class attribute, and the forwarding class collects all contributions.

## File Organization

```
modules/den/aspects/
├── core/
│   ├── avahi.nix, disko.nix, facter.nix, firmware.nix
│   ├── i18n.nix, power-mgmt.nix, security.nix, ssd.nix
│   ├── stateVersion.nix, sudo.nix, systemd.nix
│   ├── systemd-boot.nix, time.nix, utils.nix
│   └── home-manager.nix (system-level HM feature, distinct from den/home-manager.nix)
├── network/
│   ├── avahi.nix, hosts.nix, networking.nix, openssh.nix, tailscale.nix
├── nix/
│   ├── nix.nix, nixpkgs.nix
├── secrets/
│   ├── agenix.nix, impermanence.nix
├── kernel/
│   └── linux-kernel.nix
├── users/
│   ├── deterministic-uids.nix, users.nix
├── shell/ (existing)
│   └── zsh.nix
└── audio/ (existing)
    └── pipewire.nix
```

## Default Aspect

```nix
# modules/den/aspects/default.nix
{ den, ... }: {
  den.aspects.default = {
    includes = [
      den.aspects.agenix
      den.aspects.avahi
      den.aspects.deterministic-uids
      den.aspects.disko
      den.aspects.facter
      den.aspects.firmware
      den.aspects.home-manager-feature
      den.aspects.hosts-file
      den.aspects.i18n
      den.aspects.impermanence
      den.aspects.linux-kernel
      den.aspects.networking
      den.aspects.nix-daemon
      den.aspects.nixpkgs
      den.aspects.openssh
      den.aspects.power-mgmt
      den.aspects.security
      den.aspects.shell
      den.aspects.ssd
      den.aspects.stateVersion
      den.aspects.sudo
      den.aspects.systemd
      den.aspects.systemd-boot
      den.aspects.tailscale
      den.aspects.time
      den.aspects.users-config
      den.aspects.utils
    ];
  };
}
```

Then `den.aspects.bitstream.includes = [ den.aspects.default ];`

## Verification

After each batch, verify:

- `nix eval .#nixosConfigurations.bitstream.config.system.nixos.version`
  succeeds
- Existing hosts unaffected

After all batches:

- `nix build .#nixosConfigurations.bitstream.config.system.build.toplevel --dry-run`
  should get closer to building (may still need server/nix-builder features)

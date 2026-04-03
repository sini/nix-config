# Den Migration Resume Prompt

## What We're Doing

Migrating this NixOS homelab config repo from a custom flake-parts feature
system to [den](https://github.com/vic/den), an aspect-oriented configuration
framework. The migration runs in parallel — den-managed hosts coexist with the
old system.

## Branch: `feat/den`

All work is on the `feat/den` branch. The old system remains fully functional
for all hosts except `bitstream`, which has been migrated to den as a proof of
concept.

## Current State

**Bitstream is fully migrated and dry-builds cleanly.** All of bitstream's
features (default + server + nix-builder + ZFS + network-boot + cpu-amd +
gpu-amd) have been translated to den aspects.

```bash
# These all work:
nix eval .#nixosConfigurations.bitstream.config.system.nixos.version  # "25.11..."
nix eval .#nixosConfigurations.bitstream.config.networking.fqdn       # "bitstream.dev.json64.dev"
nix build .#nixosConfigurations.bitstream.config.system.build.toplevel --dry-run  # passes
```

Other hosts (cortex, blade, axon-\*, uplink, patch) still use the old feature
system and are unaffected.

## File Structure

```
modules/den/
├── systems.nix                         # Available systems declaration
├── defaults.nix                        # Global den.default + ctx.host/user includes
├── home-manager.nix                    # HM module import + hm-host/hm-user config
├── resolve-environment.nix             # Overrides den.ctx.host to enrich host.environment
│                                       # (resolves env string → full attrset from config.environments)
├── classes/
│   ├── home-platform.nix               # homeLinux/homeDarwin/homeAarch64/home64bit forwarding
│   ├── impermanence.nix                # persist/cache/persistHome/cacheHome forwarding
│   ├── secrets.nix                     # secrets → age.secrets forwarding
│   └── firewall.nix                    # firewall → networking.firewall forwarding
├── aspects/
│   ├── default.nix                     # den.aspects.default (includes all 27 base features)
│   ├── core/                           # avahi, disko, facter, firmware, i18n, power-mgmt,
│   │                                   # security, ssd, stateVersion, sudo, systemd,
│   │                                   # systemd-boot, time, utils
│   ├── network/                        # hosts, networking, openssh, tailscale,
│   │                                   # network-boot, initrd-bootstrap-keys
│   ├── nix/                            # nix, nixpkgs, nix-remote-build-server
│   ├── secrets/                        # agenix, agenix-generators, impermanence
│   ├── disk/                           # zfs-root, zfs-disk-single, zfs-diff,
│   │                                   # impermanence-zfs, btrfs-root, btrfs-disk-single,
│   │                                   # impermanence-btrfs
│   ├── users/                          # deterministic-uids, users (full ACL resolution)
│   ├── shell/                          # zsh (full HM config + plugins)
│   ├── audio/                          # pipewire (with providers)
│   ├── hardware/                       # cpu-amd, gpu-amd
│   ├── services/                       # acme, media-data-share, tang
│   ├── roles/                          # server, nix-builder
│   └── kernel/                         # linux-kernel
├── hosts/
│   └── bitstream.nix                   # First den-managed host
└── users/
    └── sini.nix                        # User aspect (for HM when users are added)
```

## Key Design Decisions

### Context Pipeline (from design spec)

```
den.ctx.environment { env }
  ├── into.host → { host }          # host.environment = resolved env
  │   └── into.user → { host, user }
  └── into.cluster → { cluster }
      └── into.k8s-service → { cluster, service }
```

Only host → user is implemented so far. Environment and cluster context stages
are deferred.

### Environment Resolution

`host.environment` is a string ("dev") in `den.hosts` definitions. The
`resolve-environment.nix` module overrides
`den.ctx.host.{provides,into.user,into.default}` using `lib.mkForce` to enrich
the host object with the resolved environment attrset before aspects see it.
This avoids infinite recursion (putting `config.environments.dev` directly on
den.hosts causes a cycle).

**TODO:** This mkForce override is fragile. Upstream a proper extension point to
den for enriching host objects before aspect application.

### Forwarding Classes (replaces collectsProviders)

Instead of the old two-phase resolver, den uses custom forwarding classes:

- **persist/cache** → `environment.persistence."/persist"` / `"/cache"`
- **persistHome/cacheHome** → `home.persistence."/persist"` / `"/cache"`
- **secrets** → `age.secrets.*`
- **firewall** → `networking.firewall.*`
- **homeLinux/homeDarwin/etc.** → `homeManager` (platform-conditional)

Aspects declare these as class attributes and forwarding classes collect them.

### User Provisioning

Full ACL-driven resolution using the existing `self.lib.users.resolveUsers`
function. Reads `config.users`, `config.environments`, `config.groups` from
flake-parts config. Den hosts need `environment` (string),
`system-access-groups`, and optionally `users` (host-level overrides) on their
definition.

### Host Definition Pattern

```nix
den.hosts.x86_64-linux.bitstream = {
  environment = "dev";                    # string, resolved by resolve-environment.nix
  system-access-groups = [ "server-access" ];
  zfs-device = "/dev/...";               # freeform metadata for aspects
  impermanence = { wipeRootOnBoot = true; wipeHomeOnBoot = false; };
  networking = { bonds = ...; interfaces = ...; };
  facts = ../../hosts/bitstream/facter.json;
  public_key = rootPath + "/.secrets/hosts/bitstream/ssh_host_ed25519_key.pub";
};

den.aspects.bitstream = {
  includes = [
    den.aspects.default
    den.aspects.zfs-disk-single
    den.aspects.impermanence-zfs
    den.aspects.zfs-diff
    den.aspects.server
    den.aspects.nix-builder
    den.aspects.cpu-amd
    den.aspects.gpu-amd
  ];
  nixos = { ... }: { /* host-specific NixOS config */ };
};
```

## What's Next

### Immediate

1. **Full `nix build`** of bitstream (dry-run passes, real build not tested yet)
2. **Deploy bitstream** with `colmena apply --on bitstream` or
   `deploy .#bitstream`

### Short-term

3. **Migrate more hosts** — cortex (workstation), blade (workstation), axon-\*
   (k8s nodes), patch (darwin laptop). Each needs its extra-features ported.
4. **Migrate workstation features** — gaming, media, desktop environments
   (hyprland, gnome, kde), dev tools, etc.
5. **Migrate darwin features** — for patch (macOS laptop)

### Medium-term

6. **Environment context stage** — implement `den.ctx.environment` as a proper
   pipeline stage instead of the mkForce override in resolve-environment.nix
7. **Cluster context stage** — implement `den.ctx.cluster → k8s-service` for
   kubernetes/nixidy configuration
8. **Upstream contributions:**
   - `take.atLeast` on `ctx.user` (allow `{ env, host, user }` signatures)
   - Host enrichment hook (replace mkForce override)
   - homeLinux/homeDarwin forwarding classes as built-in batteries
   - Two-phase collection mechanism (if forwarding classes prove insufficient)

### Cleanup

9. **Remove old feature system** once all hosts are migrated
10. **Remove `_host.nix` disabled files** for migrated hosts
11. **Consolidate duplicate code** — users/sudo/network-boot all call
    resolveUsers independently; could be computed once in the context stage

## Reference Documents

- Design spec: `docs/superpowers/specs/2026-04-02-den-migration-design.md`
- Default features spec:
  `docs/superpowers/specs/2026-04-02-default-features-migration-design.md`
- Plans: `docs/superpowers/plans/2026-04-02-den-migration.md`
- Plans: `docs/superpowers/plans/2026-04-02-default-features-migration.md`
- ACL design: `docs/ACL.md`

## Reference Repos

- Den source: `/home/sini/Documents/repos/den-configs/den`
- Gwenodai example: `/home/sini/Documents/repos/den-configs/gwenodai-nixos`

## Typed Settings Pattern

Aspects declare typed settings on `den.schema.host` in `modules/den/schema.nix`.
Hosts set them under `settings.<aspect-name>.<option>` with validation and
defaults.

```nix
# In modules/den/schema.nix — declare settings
den.schema.host = _: {
  options.settings.my-aspect = {
    myOption = lib.mkOption { type = lib.types.bool; default = true; };
  };
};

# In the aspect — read typed settings (no `or` fallbacks needed)
den.aspects.my-aspect = den.lib.perHost ({ host }: {
  nixos = lib.mkIf host.settings.my-aspect.myOption { /* config */ };
});

# In the host — set typed settings
den.hosts.x86_64-linux.myhost = {
  settings.my-aspect.myOption = false;
};
```

## Key Patterns for New Aspects

```nix
# Simple system aspect
{ den, ... }: {
  den.aspects.foo = den.lib.perHost {
    nixos = { pkgs, ... }: { /* NixOS config */ };
  };
}

# Aspect needing host data
{ den, ... }: {
  den.aspects.foo = den.lib.perHost ({ host }: {
    nixos = { /* uses host.environment, host.networking, host.settings, etc. */ };
  });
}

# Aspect with forwarding classes
{ den, lib, ... }: {
  den.aspects.foo = {
    includes = lib.attrValues den.aspects.foo._;
    _ = {
      config = den.lib.perHost { nixos = { /* main config */ }; };
      impermanence = den.lib.perHost { persist.directories = [ "/var/lib/foo" ]; };
      secrets = den.lib.perHost { secrets.foo-key = { generator.script = "ssh-key"; }; };
      firewall = den.lib.perHost { firewall.allowedTCPPorts = [ 8080 ]; };
    };
  };
}

# Aspect needing resolved users (for SSH keys, etc.)
{ den, self, config, lib, ... }:
let
  inherit (self.lib.users) resolveUsers getSshKeysForGroup;
  canonicalUsers = config.users;
  groupDefs = config.groups;
in {
  den.aspects.foo = den.lib.perHost ({ host }: let
    resolvedUsers = resolveUsers lib canonicalUsers host.environment
      { hostname = host.name; inherit (host) system-access-groups; users = host.users or {}; }
      groupDefs;
  in { nixos = { /* use resolvedUsers */ }; });
}
```

## Statix/Treefmt Rules

- Single `_ = { ... }` block for sub-aspects (no repeated `_.foo`, `_.bar`)
- Single `den = { ... }` block for multiple den.\* attributes
- Run `treefmt` before committing — it reformats nix files
- Stage with `git add` before `nix eval` — nix only sees staged/committed files
- `# deadnix: skip` above unused args that are actually used (like `class` in
  forwarding)

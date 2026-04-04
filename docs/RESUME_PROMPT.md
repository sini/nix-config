# Den Migration Resume Prompt

## What We're Doing

Migrating this NixOS homelab config repo from a custom flake-parts feature
system to [den](https://github.com/vic/den), an aspect-oriented configuration
framework. The migration runs in parallel — den-managed hosts coexist with the
old system.

## Branch: `feat/den`

All work is on the `feat/den` branch.

## Current State (2026-04-03)

**All 8 hosts eval successfully on den.** ~200 aspects migrated covering all
features from core/, features/, services/, and apps/.

```bash
# All hosts eval:
for h in bitstream axon-01 axon-02 axon-03 uplink blade cortex; do
  nix eval .#nixosConfigurations.$h.config.system.nixos.version
done
nix eval .#darwinConfigurations --apply 'x: builtins.attrNames x'  # [ "patch" ]
```

| Host          | Channel        | Type              | Environment | Users            |
| ------------- | -------------- | ----------------- | ----------- | ---------------- |
| bitstream     | nixos-unstable | NixOS server      | dev         | sini             |
| axon-01/02/03 | nixos-unstable | NixOS k8s         | prod        | sini             |
| uplink        | nixos-unstable | NixOS server      | prod        | sini             |
| blade         | nixpkgs-master | NixOS laptop      | dev         | sini, shuo, will |
| cortex        | nixpkgs-master | NixOS workstation | dev         | sini, shuo, will |
| patch         | nixos-stable   | Darwin laptop     | dev         | sini             |

## File Structure

```
modules/den/
├── systems.nix                         # Available systems
├── defaults.nix                        # Global den.default + ctx.host/user includes
├── schema.nix                          # Typed host options (channel, settings.*)
├── home-manager.nix                    # Per-channel HM module import + hm config
├── resolve-environment.nix             # enrichHost: environment, ipv4/ipv6, cluster, users
├── flake-outputs.nix                   # darwinConfigurations merge semantics
├── environments/
│   ├── options.nix                     # den.environments type + findHostsByFeature
│   ├── prod.nix, prod-users.nix        # Production environment data + ACL
│   └── dev.nix, dev-users.nix          # Development environment data + ACL
├── classes/
│   ├── home-platform.nix               # homeLinux/homeDarwin/homeAarch64/home64bit
│   ├── impermanence.nix                # persist/cache/persistHome/cacheHome
│   ├── secrets.nix                     # secrets → age.secrets
│   └── firewall.nix                    # firewall → networking.firewall
├── aspects/                            # ~200 aspect files organized by category
│   ├── default.nix                     # includes all 27 base features
│   ├── core/                           # 14 core system aspects
│   ├── network/                        # 8 network aspects
│   ├── nix/                            # 3 nix aspects
│   ├── secrets/                        # 3 secrets/impermanence aspects
│   ├── disk/                           # 7 ZFS/BTRFS/XFS/ceph aspects
│   ├── users/                          # 2 user provisioning aspects
│   ├── shell/                          # zsh (full HM config)
│   ├── audio/                          # pipewire
│   ├── hardware/                       # ~17 hardware aspects (cpu, gpu, peripherals)
│   ├── desktop/                        # 12 desktop/WM aspects
│   ├── login/                          # 3 login manager aspects
│   ├── services/                       # ~30 service aspects (k8s, monitoring, web, media)
│   ├── roles/                          # ~20 role aspects (workstation, gaming, dev, etc.)
│   ├── apps/                           # ~60 app aspects (shell, dev, media, gaming, etc.)
│   ├── virtualization/                 # libvirt, microvm, podman
│   ├── runtime/                        # nix-ld
│   └── system/                         # ananicy
├── hosts/
│   ├── bitstream.nix, axon-{01,02,03}.nix, uplink.nix
│   ├── blade.nix, cortex.nix, patch.nix
│   └── _namespaces.nix                 # disabled (subagent artifact, needs review)
└── users/
    └── sini.nix                        # User aspect (for HM when den users added)
```

## Key Architecture

### Channel Schema (`den.schema.host`)

Hosts set `channel` which determines nixpkgs + home-manager + nix-darwin
versions:

```nix
den.hosts.x86_64-linux.cortex = {
  channel = "nixpkgs-master";  # or nixos-unstable, nixos-stable, nixpkgs-stable-darwin
  environment = "dev";
  # channel automatically sets host.instantiate and matching HM module
};
```

Available channels: `nixos-unstable`, `nixpkgs-master`, `nixos-stable`,
`nixpkgs-stable-darwin`. Each bundles matching nixpkgs lib.nixosSystem +
home-manager module.

### Environment Resolution (`resolve-environment.nix`)

`enrichHost` runs before aspects see the host. It adds:

- `host.environment` — resolved from `den.environments.${host.environment}`
- `host.ipv4` / `host.ipv6` — extracted from first networking interface
- `host.cluster` — looked up from `config.clusters`
- `host.users.{all, enabled, enabledNames}` — ACL-resolved users

Environments are den-native (`den.environments`) with typed schema, breaking the
cycle that existed with `config.environments`.

### Forwarding Classes

Custom classes that collect contributions from active aspects:

- **persist/cache** → `environment.persistence."/persist"` / `"/cache"`
- **persistHome/cacheHome** → `home.persistence."/persist"` / `"/cache"`
- **secrets** → `age.secrets.*`
- **firewall** → `networking.firewall.*`
- **homeLinux/homeDarwin/etc.** → `homeManager` (platform-conditional via guard)

### User Provisioning

Centralized in `enrichHost` — calls `self.lib.users.resolveUsers` with canonical
users, den environment, host metadata, and group definitions. Aspects access
`host.users.enabled` (resolved user attrset) and `host.users.enabledNames`.

### Per-User Feature Overrides

Available via den's `mutual-provider` (already in `den.default.includes`):

```nix
den.aspects.cortex = {
  provides.sini = {
    homeManager = { ... };  # sini-specific config
  };
  provides.to-users = { user, ... }: {
    homeManager = lib.mkIf (user.name == "sini") { ... };
  };
};
```

## Typed Settings Pattern

Aspects declare typed settings on `den.schema.host` in `modules/den/schema.nix`.

```nix
# Schema declares options with defaults
den.schema.host = _: {
  options.settings.my-aspect.myOption = lib.mkOption {
    type = lib.types.bool; default = true;
  };
};

# Aspect reads typed settings
den.aspects.my-aspect = den.lib.perHost ({ host }: {
  nixos = lib.mkIf host.settings.my-aspect.myOption { ... };
});

# Host sets values
den.hosts.x86_64-linux.myhost.settings.my-aspect.myOption = false;
```

Current schema settings: linux-kernel, impermanence, tailscale, zfs-disk-single,
btrfs-disk-single, network-manager, ceph-device-allocation, xfs-disk-longhorn,
bgp, cilium-bgp, thunderbolt-mesh-of, k3s.

## Key Patterns for New Aspects

```nix
# Simple system aspect
{ den, ... }: {
  den.aspects.foo = den.lib.perHost {
    nixos = { pkgs, ... }: { ... };
  };
}

# Aspect needing host data
{ den, ... }: {
  den.aspects.foo = den.lib.perHost ({ host }: {
    nixos = { ... }: { /* host.environment, host.settings, host.users.enabled */ };
  });
}

# Aspect with forwarding classes (impermanence, secrets, firewall)
{ den, lib, ... }: {
  den.aspects.foo = {
    includes = lib.attrValues den.aspects.foo._;
    _ = {
      config = den.lib.perHost { nixos = { ... }; };
      impermanence = den.lib.perHost { persist.directories = [ "/var/lib/foo" ]; };
      secrets = den.lib.perHost { secrets.foo-key = { generator.script = "ssh-key"; }; };
      firewall = den.lib.perHost { firewall.allowedTCPPorts = [ 8080 ]; };
    };
  };
}

# Aspect using flake inputs (MUST be at top-level, NOT in NixOS module args)
{ den, inputs, ... }: {
  den.aspects.foo = den.lib.perHost {
    nixos = {
      imports = [ inputs.some-flake.nixosModules.default ];  # inputs from closure
    };
  };
}
```

**IMPORTANT:** Never use `{ inputs, ... }:` inside a NixOS/HM module function.
This causes infinite recursion. Always get `inputs` from the flake-parts module
level (top-level args) and close over it.

## Dry-Run Build Status

| Host          | Status    | Notes                                                          |
| ------------- | --------- | -------------------------------------------------------------- |
| bitstream     | OK        | Server, dry-run clean                                          |
| axon-01/02/03 | OK        | K8s nodes, dry-run clean                                       |
| blade         | OK        | Laptop workstation, dry-run clean                              |
| uplink        | ERROR     | kanidm oidc-secrets gets "prod" string instead of resolved env |
| cortex        | ERROR     | ollama GPU detection via config refs (NixOS eval order)        |
| patch         | Eval only | Darwin, not dry-run tested                                     |

## Remaining TODOs

### Immediate — Fix Remaining Dry-Run Failures

- [ ] **uplink**: kanidm `provision-oidc-secrets` gets `"prod"` string instead
      of resolved environment attrset. The `environment` NixOS module arg
      (injected via defaults.nix) should be the resolved attrset, but something
      in kanidm's perHost chain isn't receiving it correctly.
- [ ] **cortex**: ollama aspect GPU detection uses `config.hardware.*` which may
      not be available at eval time. May need a settings-based approach instead.

### Per-Channel Home-Manager

- [ ] Den's built-in HM provider uses its own `inputs.home-manager`. Our repo
      has 4 HM versions (unstable, master, stable, stable-darwin) paired with
      channels. Currently all hosts use den's HM version regardless of channel.
      Options: override den's getModule, make provider channel-aware, or add
      `inputs.home-manager.follows` to den input.

### Host-to-User Aspect Flow

- [ ] `perUser` blocks from host-level aspects do NOT flow to users
      automatically. The host's aspect chain includes stylix (with perUser home
      config), but users only get their own aspect chain applied at the user
      context stage. Workaround: use `homeManagerIntegration.followSystem` for
      stylix, use `home-manager.sharedModules` for system-wide HM modules. Needs
      investigation into den's context pipeline to understand if this is
      expected behavior or a bug in our enrichHost override.

### Feature Gaps

- [ ] `excluded-features` — den doesn't support excluding aspects
- [ ] `microvm-cuda` aspect — referenced by cortex but not created
- [ ] `hasFeature` equivalent — aspects that conditionally behave based on other
      active aspects need a den-native solution (currently hardcoded/stubbed)
- [ ] `findHostsByFeature` only filters by environment name, not by aspect chain
- [ ] Many service aspects have hardcoded settings (noted as TODO in files)
- [ ] k8s-update-manifests pre-commit hook broken (`config.features` removed)

### Environment / Context

- [ ] `den.ctx.environment` as a proper pipeline stage (currently just data)
- [ ] `den.ctx.cluster → k8s-service` for kubernetes/nixidy configuration

### Infrastructure

- [ ] `resolve-environment.nix` uses `lib.mkForce` — upstream extension point
- [ ] `hosts.nix` and `ssh.nix` still read old
      `config.hosts`/`config.environments`
- [ ] Darwin (patch) needs full validation
- [ ] Legacy system in `modules/_legacy/` — can be deleted once fully validated

### Upstream Contributions to Den

- [ ] Host enrichment hook (replace mkForce)
- [ ] `take.atLeast` on `ctx.user`
- [ ] homeLinux/homeDarwin as built-in batteries
- [ ] Channel/instantiate pattern docs
- [ ] Investigate perUser flow from host aspects to users

## Reference Documents

- Design spec: `docs/superpowers/specs/2026-04-02-den-migration-design.md`
- Default features spec:
  `docs/superpowers/specs/2026-04-02-default-features-migration-design.md`
- ACL design: `docs/ACL.md`

## Reference Repos

- Den source: `/home/sini/Documents/repos/den-configs/den`
- Gwenodai example: `/home/sini/Documents/repos/den-configs/gwenodai-nixos`

## Statix/Treefmt Rules

- Single `_ = { ... }` block for sub-aspects (no repeated `_.foo`, `_.bar`)
- Single `den = { ... }` block for multiple den.\* attributes
- Run `treefmt` before committing
- Stage with `git add` before `nix eval` — nix only sees staged/committed files
- `# deadnix: skip` above unused args that are actually used

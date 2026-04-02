# Den Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers-extended-cc:subagent-driven-development (if subagents available) or superpowers-extended-cc:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a parallel den-based configuration system under `modules/den/` that coexists with the current flake-parts system, starting with foundational wiring and one host as proof of concept.

**Architecture:** Den is imported as a flake input alongside the existing system. Custom context stages (environment, cluster, k8s-service) and schemas are defined under `modules/den/`. Aspects (migrated features) live under `modules/den/aspects/`. Both systems coexist — den outputs are suffixed (e.g., `cortex-den`) to avoid conflicts.

**Tech Stack:** Nix, den, flake-parts, import-tree, home-manager

**Reference repos:**
- Den source: `/home/sini/Documents/repos/den-configs/den`
- Gwenodai example: `/home/sini/Documents/repos/den-configs/gwenodai-nixos`
- Design spec: `docs/superpowers/specs/2026-04-02-den-migration-design.md`

---

### Task 0: Add den flake input and bootstrap module

**Goal:** Wire den into the flake so `den.aspects`, `den.hosts`, `den.ctx` are available in all modules under `modules/den/`.

**Files:**
- Modify: `modules/flake-parts/devtools/flake-file.nix` (add den input + uncomment dendritic import)

**Important:** Do NOT create a separate `modules/den/inputs.nix` that imports `den.flakeModule`.
The dendritic flakeModule (`inputs.den.flakeModules.dendritic`) already imports `den.flakeModule`
internally. Importing it twice causes option-already-declared errors. Gwenodai confirms this
pattern — it only imports via the dendritic module in flake-file.

**Acceptance Criteria:**
- [ ] `den` appears in `flake.lock` after `nix-flake-update`
- [ ] `den.aspects`, `den.hosts`, `den.ctx` are accessible in modules under `modules/den/`
- [ ] Existing configuration still builds without errors

**Verify:** `nix-flake-build cortex` → builds successfully (existing system unaffected)

**Steps:**

- [ ] **Step 1: Add den as a flake input and enable dendritic import**

In `modules/flake-parts/devtools/flake-file.nix`:

1. Uncomment the den dendritic import (line 5):
```nix
imports = [
  (inputs.flake-file.flakeModules.dendritic or { })
  (inputs.den.flakeModules.dendritic or { })
];
```

2. Add den to `flake-file.inputs`:
```nix
den = {
  url = "github:vic/den";
  inputs.nixpkgs.follows = "nixpkgs-unstable";
};
```

- [ ] **Step 2: Create systems declaration**

Create `modules/den/systems.nix` to declare available systems:

```nix
{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
}
```

- [ ] **Step 3: Regenerate flake.nix and verify**

```bash
# Regenerate flake.nix with new input
nix run .#flake-file
# Update lock file
nix-flake-update
# Verify existing build still works
nix-flake-build cortex
```

---

### Task 1: Define den defaults and custom forwarding classes

**Goal:** Set up global den defaults (includes for all hosts/users) and the custom forwarding classes (`homeLinux`, `homeDarwin`, `os`) that aspects will use.

**Files:**
- Create: `modules/den/defaults.nix` (global includes and providers)
- Create: `modules/den/classes/home-platform.nix` (homeLinux/homeDarwin forwarding)

**Acceptance Criteria:**
- [ ] `den.default.includes` contains mutual-provider, inputs', self'
- [ ] `homeLinux` class forwards to `homeManager` only on nixos hosts
- [ ] `homeDarwin` class forwards to `homeManager` only on darwin hosts
- [ ] No eval errors when den modules are loaded

**Verify:** `nix-flake-build cortex` → still builds (den modules loaded but no den hosts defined yet)

**Steps:**

- [ ] **Step 1: Create defaults module**

Create `modules/den/defaults.nix` following gwenodai's pattern. Include global
providers here, plus hostname and define-user so they don't need repeating per host/user:

```nix
{ den, ... }: {
  den.default.includes = [
    den._.mutual-provider
    den._.inputs'
    den._.self'
  ];

  # Global host-level includes (apply to all den hosts)
  den.ctx.host.includes = [
    den._.hostname
  ];

  # Global user-level includes (apply to all den users)
  den.ctx.user.includes = [
    den._.define-user
  ];
}
```

- [ ] **Step 2: Create platform-conditional home forwarding classes**

Create `modules/den/classes/home-platform.nix`.

Forwarding classes are plain `{ class, aspect-chain }` functions (NOT wrapped in
`den.lib.perHost` — that's for aspects with class keys). The `class` parameter IS
the host class ("nixos"/"darwin"), so we use it directly for platform filtering.
This follows the same pattern as den's built-in `os-class` provider.

```nix
{ den, lib, ... }:
let
  # Forward homeLinux -> homeManager, only on nixos hosts
  homeLinux-class = { class, aspect-chain }: den._.forward {
    each = lib.optional (class == "nixos") true;
    fromClass = _: "homeLinux";
    intoClass = _: "homeManager";
    intoPath = _: [ ];
    fromAspect = _: lib.head aspect-chain;
  };

  # Forward homeDarwin -> homeManager, only on darwin hosts
  homeDarwin-class = { class, aspect-chain }: den._.forward {
    each = lib.optional (class == "darwin") true;
    fromClass = _: "homeDarwin";
    intoClass = _: "homeManager";
    intoPath = _: [ ];
    fromAspect = _: lib.head aspect-chain;
  };
in
{
  # Include in den.ctx.default so they apply everywhere (matching os-class pattern)
  den.ctx.default.includes = [
    homeLinux-class
    homeDarwin-class
  ];
}
```

- [ ] **Step 3: Verify no eval errors**

```bash
nix-flake-build cortex
```

---

### Task 2: Define home-manager integration aspect

**Goal:** Configure home-manager defaults for den hosts, following gwenodai's pattern.

**Files:**
- Create: `modules/den/home-manager.nix`

**Acceptance Criteria:**
- [ ] home-manager useUserPackages, useGlobalPkgs, backupFileExtension configured
- [ ] stateVersion set via mkDefault
- [ ] Integration uses den's hm-host and hm-user context stages

**Verify:** `nix-flake-build cortex` → no eval errors

**Steps:**

- [ ] **Step 1: Create home-manager integration**

Create `modules/den/home-manager.nix`:

```nix
{ den, lib, ... }: {
  den.ctx.hm-host.includes = [ den.aspects.home-manager._.nixConfig ];
  den.ctx.hm-user.includes = [ den.aspects.home-manager._.hmConfig ];

  den.aspects.home-manager = {
    _.nixConfig = den.lib.perHost {
      nixos.home-manager = {
        useUserPackages = lib.mkDefault true;
        useGlobalPkgs = lib.mkDefault true;
        backupFileExtension = lib.mkDefault "backup";
        overwriteBackup = lib.mkDefault true;
      };
    };

    _.hmConfig = {
      homeManager.home.stateVersion = lib.mkDefault "25.11";
    };
  };
}
```

- [ ] **Step 2: Verify**

```bash
nix-flake-build cortex
```

---

### Task 3: Migrate first simple aspect (shell/zsh)

**Goal:** Migrate the `zsh` feature to a den aspect as proof that the aspect system works end-to-end.

**Files:**
- Create: `modules/den/aspects/shell/zsh.nix`
- Reference: `modules/features/login/zsh.nix` and `modules/apps/shell/zsh.nix` (check both locations for zsh config)

**Acceptance Criteria:**
- [ ] `den.aspects.zsh` defines equivalent nixos and homeManager config
- [ ] Aspect follows den patterns (den.lib.perHost/perUser where appropriate)
- [ ] No eval errors

**Verify:** `nix-flake-build cortex` → no eval errors

**Steps:**

- [ ] **Step 1: Read current zsh feature**

Find the zsh feature source. Check `modules/features/login/zsh.nix`, `modules/apps/shell/zsh.nix`,
and `modules/core/shell/zsh.nix`. The feature may span multiple files. Read all relevant ones.

- [ ] **Step 2: Create den aspect**

Create `modules/den/aspects/shell/zsh.nix` translating the feature's `linux`/`darwin`/`home` modules to den aspect classes (`nixos`/`darwin`/`homeManager`). Use `den.lib.perHost` for system-level config and `den.lib.perUser` for home-manager config where needed. Follow gwenodai's sub-aspect pattern:

```nix
{ den, lib, ... }: {
  den.aspects.zsh = {
    includes = lib.attrValues den.aspects.zsh._;

    _.enable = den.lib.perHost {
      nixos.programs.zsh.enable = lib.mkDefault true;
    };

    _.config = {
      homeManager = { pkgs, lib, ... }: {
        programs.zsh = {
          enable = lib.mkDefault true;
          # ... migrated from current feature
        };
      };
    };
  };
}
```

Exact content depends on what the current feature defines — read it first.

- [ ] **Step 3: Verify**

```bash
nix-flake-build cortex
```

---

### Task 4: Define first den host (cortex-den) and user (sini)

**Goal:** Declare `cortex-den` as a den host with user `sini`, producing a `nixosConfigurations.cortex-den` output that evaluates successfully.

**Files:**
- Create: `modules/den/hosts/cortex-den.nix` (host declaration + aspect)
- Create: `modules/den/users/sini.nix` (user aspect)

**Acceptance Criteria:**
- [ ] `den.hosts.x86_64-linux.cortex-den` is declared with user sini
- [ ] `den.aspects.cortex-den` includes the zsh aspect and basic host config
- [ ] `den.aspects.sini` defines user identity and home-manager basics
- [ ] `nix eval .#nixosConfigurations.cortex-den.config.system.nixos.version` returns a version string
- [ ] Existing `nixosConfigurations.cortex` is unaffected

**Verify:** `nix eval .#nixosConfigurations.cortex-den.config.system.nixos.version` → version string

**Steps:**

- [ ] **Step 1: Create host declaration and aspect**

Create `modules/den/hosts/cortex-den.nix`:

```nix
{ den, lib, inputs, ... }: {
  den.hosts.x86_64-linux.cortex-den = {
    users.sini.classes = [ "homeManager" ];
  };

  # den._.hostname and den._.define-user are set globally in defaults.nix
  den.aspects.cortex-den = {
    includes = [
      den.aspects.zsh
    ];

    nixos = { pkgs, lib, modulesPath, ... }: {
      # Minimal bootable config for eval testing
      imports = [ (modulesPath + "/profiles/minimal.nix") ];
      boot.loader.grub.enable = lib.mkDefault false;
      fileSystems."/".device = "/dev/null";
      nixpkgs.hostPlatform = "x86_64-linux";
    };
  };
}
```

- [ ] **Step 2: Create user aspect**

Create `modules/den/users/sini.nix`:

```nix
{ den, lib, ... }: {
  den.aspects.sini = {
    includes = [
      den._.primary-user
      den.aspects.zsh
    ];

    user = {
      isNormalUser = true;
      description = "Jason Bowman";
    };

    homeManager = { lib, ... }: {
      home.stateVersion = lib.mkDefault "25.11";
    };
  };
}
```

- [ ] **Step 3: Verify eval**

```bash
nix eval .#nixosConfigurations.cortex-den.config.system.nixos.version
# Expected: version string like "25.11..."
```

- [ ] **Step 4: Verify existing host unaffected**

```bash
nix-flake-build cortex
# Expected: builds successfully, unchanged
```

---

### Task 5: Migrate a second aspect with providers (pipewire)

**Goal:** Migrate pipewire feature to demonstrate the provider pattern and aspect composition with includes.

**Files:**
- Create: `modules/den/aspects/audio/pipewire.nix`
- Reference: `modules/features/hardware/audio.nix` (the feature is named `audio`, not `pipewire`)

**Acceptance Criteria:**
- [ ] `den.aspects.pipewire` defines nixos config for pipewire
- [ ] If the current feature has providers (e.g., low-latency), they are migrated as `provides`
- [ ] Aspect can be included by other aspects

**Verify:** `nix-flake-build cortex` → no eval errors

**Steps:**

- [ ] **Step 1: Read current pipewire feature**

Read `modules/features/hardware/audio.nix` to understand system/home modules and any providers.

- [ ] **Step 2: Create den aspect**

Create `modules/den/aspects/audio/pipewire.nix` translating the feature. If it has `provides.low-latency`, create:

```nix
{ den, lib, ... }: {
  den.aspects.pipewire = {
    includes = lib.attrValues den.aspects.pipewire._;

    _.enable = den.lib.perHost {
      nixos = { lib, ... }: {
        services.pipewire = {
          enable = lib.mkDefault true;
          # ... migrated config
        };
      };
    };

    # If provider exists:
    provides.low-latency = den.lib.perHost {
      nixos = { ... }: {
        # low-latency specific config
      };
    };
  };
}
```

- [ ] **Step 3: Add to cortex-den includes and verify**

Add `den.aspects.pipewire` to `cortex-den`'s includes and verify eval.

---

### Task 6: Add cortex-den to cortex's facter hardware config

**Goal:** Make cortex-den use the real hardware configuration from cortex so it can actually build (not just eval).

**Files:**
- Modify: `modules/den/hosts/cortex-den.nix` (add hardware config, real boot config)

**Acceptance Criteria:**
- [ ] cortex-den imports cortex's facter.json or hardware configuration
- [ ] `nix-flake-build cortex-den` succeeds (full build, not just eval)

**Verify:** `nix-flake-build cortex-den` → build succeeds

**Steps:**

- [ ] **Step 1: Add hardware config to cortex-den aspect**

Modify `modules/den/hosts/cortex-den.nix` to import cortex's hardware:

```nix
den.aspects.cortex-den = {
  # ... existing includes ...
  nixos = { lib, ... }: {
    imports = [
      inputs.nixos-facter-modules.nixosModules.facter
    ];
    facter.reportPath = ../../../hosts/cortex/facter.json;
    # Real boot config instead of minimal stub
    boot.loader.systemd-boot.enable = lib.mkDefault true;
    nixpkgs.hostPlatform = "x86_64-linux";
  };
};
```

- [ ] **Step 2: Build**

```bash
nix-flake-build cortex-den
```

This will likely surface missing aspects (features cortex requires but we haven't migrated).
**Strategy: create no-op stub aspects** for any missing dependencies rather than migrating them
fully. The goal is to prove the pipeline works, not to migrate all features in this phase.
For example, if `networking` is required:

```nix
# modules/den/aspects/stubs.nix
{ den, ... }: {
  den.aspects.networking = {}; # stub — to be migrated later
  den.aspects.nix = {};
  # ... add stubs as needed
};
```

---

### Task 7: Commit and document progress

**Goal:** Commit all work with clear messages and document the migration status.

**Files:**
- All files created/modified in tasks 0-6

**Acceptance Criteria:**
- [ ] All changes committed with descriptive messages
- [ ] `modules/den/` structure is clean and follows established patterns

**Verify:** `git status` → clean working tree

**Steps:**

- [ ] **Step 1: Stage and commit in logical groups**

```bash
# Foundation
git add modules/flake-parts/devtools/flake-file.nix modules/den/inputs.nix modules/den/defaults.nix
git commit -m "feat(den): add den input and bootstrap module"

# Classes and home-manager
git add modules/den/classes/ modules/den/home-manager.nix
git commit -m "feat(den): add forwarding classes and home-manager integration"

# Aspects
git add modules/den/aspects/
git commit -m "feat(den): migrate zsh and pipewire aspects"

# Host and user
git add modules/den/hosts/ modules/den/users/
git commit -m "feat(den): add cortex-den host and sini user"
```

---

## File Structure

```
modules/den/
├── systems.nix                   # Declare available systems
├── defaults.nix                  # Global den.default/ctx includes
├── home-manager.nix              # HM integration (hm-host, hm-user ctx)
├── classes/
│   └── home-platform.nix         # homeLinux/homeDarwin forwarding
├── aspects/
│   ├── shell/
│   │   └── zsh.nix               # Migrated zsh feature
│   ├── audio/
│   │   └── pipewire.nix          # Migrated audio/pipewire feature
│   └── stubs.nix                 # No-op stubs for unmigrated features
├── hosts/
│   └── cortex-den.nix            # First den host (parallel to cortex)
└── users/
    └── sini.nix                  # First den user
```

## Notes

- All den modules are auto-imported via import-tree (same as existing modules)
- Den hosts output as `nixosConfigurations.cortex-den` to avoid conflicting with existing `cortex`
- Once the parallel system is validated, migration continues by porting more features to aspects
- The environment/cluster context stages are deferred to a later phase — this plan focuses on proving the host/user/aspect pipeline works end-to-end

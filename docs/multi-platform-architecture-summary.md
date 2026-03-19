# Multi-Platform Architecture - Summary

## Revised Design Based on Feedback

### Key Design Decisions

1. **No separate `platform` field** - Platform is detected from `system`
   architecture suffix (`-linux` vs `-darwin`)
1. **Rename `nixos` → `system` + `linux`** - Better semantic naming for
   cross-platform support
1. **Keep backward compatibility** - Legacy `nixos` key and `nixosConfiguration`
   still work during migration
1. **Unified `systemConfiguration`** - Replaces `nixosConfiguration` for both
   NixOS and Darwin

---

## Feature Module Types

### New Module Type System

```nix
features.example = {
  name = "example";

  # Cross-platform system modules (works on NixOS AND Darwin)
  system = { config, pkgs, ... }: {
    # Example: nix settings, user management, etc.
  };

  # Linux-specific system modules (NixOS only)
  linux = { config, pkgs, ... }: {
    # Example: systemd services, kernel modules, etc.
  };

  # Darwin-specific system modules (macOS only)
  darwin = { config, pkgs, ... }: {
    # Example: launchd agents, macOS-specific settings
  };

  # Home-manager modules (works everywhere)
  home = { config, pkgs, ... }: {
    # Example: dotfiles, user applications
  };

  requires = ["dependency"];
  excludes = ["conflict"];
};
```

### Module Collection Logic

```nix
# For a NixOS host (system = "x86_64-linux"):
collected = system + linux + home

# For a Darwin host (system = "aarch64-darwin"):
collected = system + darwin + home

# Legacy (during migration):
nixos = treated as (system + linux)
```

---

## Host Configuration

### Unified Host Definition

```nix
hosts.hostname = {
  # Platform auto-detected from system architecture
  system = "x86_64-linux";      # → NixOS
  # OR
  system = "aarch64-darwin";    # → Darwin

  # Unified system configuration (replaces nixosConfiguration)
  systemConfiguration = ./default.nix;

  # Everything else stays the same
  roles = ["workstation"];
  features = ["docker"];
  environment = "dev";
  users = { ... };
};
```

### Platform Detection

```nix
# In the builder
isDarwin = lib.hasSuffix "-darwin" hostOptions.system;
isLinux = lib.hasSuffix "-linux" hostOptions.system;

# Dispatch to correct builder
if isLinux then mkNixosHost { ... }
else if isDarwin then mkDarwinHost { ... }
else throw "Unsupported system: ${hostOptions.system}";
```

---

## Architecture Flow

```
mkHost
  │
  ├─ Detect platform from system architecture
  │  ├─ "*-linux" → mkNixosHost
  │  └─ "*-darwin" → mkDarwinHost
  │
  ├─ prepareHostContext (platform-agnostic)
  │  ├─ Select package set (stable/unstable)
  │  ├─ Resolve features from roles
  │  ├─ Resolve dependencies
  │  └─ Compute enabled users
  │
  ├─ collectPlatformSystemModules
  │  ├─ Collect "system" modules (always)
  │  ├─ Collect "linux" OR "darwin" modules (based on platform)
  │  └─ (Legacy: also collect "nixos" modules for compatibility)
  │
  ├─ makeHomeConfig (platform-agnostic)
  │  ├─ Aggregate user features
  │  ├─ Resolve dependencies
  │  └─ Collect "home" modules
  │
  └─ Build system configuration
     ├─ NixOS: lib.nixosSystem + nixosModules.home-manager
     └─ Darwin: darwin.lib.darwinSystem + darwinModules.home-manager
```

---

## Migration Strategy

### Phase 1: Add Support (No Breaking Changes)

- ✅ Add `system`, `linux`, `darwin` module collectors
- ✅ Add platform detection from system architecture
- ✅ Keep `nixos` key working (backward compatibility)
- ✅ All existing hosts continue to work

### Phase 2: Add Darwin Support

- Add `nix-darwin` to flake inputs
- Add `x86_64-darwin` to system enum
- Implement `mkDarwinHost` builder
- Create sample darwin host

### Phase 3: Rename Configuration Option

- Add `systemConfiguration` option
- Keep `nixosConfiguration` as deprecated alias
- Update documentation

### Phase 4: Feature Migration (Gradual)

- Migrate cross-platform features: `nixos` → `system`
- Migrate Linux-only features: `nixos` → `linux`
- Add Darwin modules to applicable features
- No rush - can happen incrementally

---

## Example Feature Migrations

### Cross-Platform Feature (SSH)

```nix
# Before
features.ssh.nixos = { services.openssh.enable = true; };

# After
features.ssh.system = { services.openssh.enable = true; };
```

### Linux-Only Feature (GPU)

```nix
# Before
features.gpu-nvidia.nixos = { hardware.nvidia... };

# After
features.gpu-nvidia.linux = { hardware.nvidia... };
```

### Platform-Specific Feature (Power Management)

```nix
# Before
features.power-mgmt.nixos = { /* systemd-based */ };

# After
features.power-mgmt = {
  system = { /* shared config */ };
  linux = { /* systemd-based */ };
  darwin = { /* macOS power management */ };
};
```

---

## Benefits of This Approach

### ✅ Simpler

- No separate `platform` field needed
- System architecture implies platform
- Less configuration complexity

### ✅ Clearer Semantics

- `system` = works everywhere
- `linux` = Linux-specific
- `darwin` = Darwin-specific
- Clear intent from naming

### ✅ Backward Compatible

- All existing NixOS hosts work unchanged
- `nixos` key still works during migration
- `nixosConfiguration` still works with fallback
- Gradual migration possible

### ✅ Maintainable

- Most logic is platform-agnostic
- Platform differences isolated to specific sections
- Easy to add new platforms in future

---

## Implementation Checklist

**Phase 1: Foundation** (No Breaking Changes)

- [ ] Add `collectSystemModules`, `collectLinuxModules`, `collectDarwinModules`
- [ ] Add `collectPlatformSystemModules` with platform detection
- [ ] Keep `collectNixosModules` for backward compatibility
- [ ] Test: All existing NixOS hosts build unchanged

**Phase 2: Darwin Support**

- [ ] Add `nix-darwin` to flake inputs
- [ ] Add `x86_64-darwin` to system enum in host-options.nix
- [ ] Implement `mkDarwinHost` builder
- [ ] Implement `makeDarwinHomeManagerModule`
- [ ] Update `mkHost` to dispatch based on system
- [ ] Test: Create and build sample darwin host

**Phase 3: Configuration Rename**

- [ ] Add `systemConfiguration` option
- [ ] Add fallback to `nixosConfiguration`
- [ ] Update builder to use new name
- [ ] Test: Both old and new names work

**Phase 4: Documentation**

- [ ] Update feature documentation
- [ ] Add darwin host examples
- [ ] Document migration path
- [ ] Update CLAUDE.md

**Phase 5: Feature Migration** (Gradual)

- [ ] Identify cross-platform features → migrate to `system`
- [ ] Identify Linux-only features → migrate to `linux`
- [ ] Add darwin support to applicable features
- [ ] Remove deprecated `nixos` key (after full migration)

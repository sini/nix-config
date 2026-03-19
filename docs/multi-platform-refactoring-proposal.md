# Multi-Platform Configuration Refactoring Proposal

## Current State Analysis

### Home Manager Integration Today

Home-manager is currently **deeply integrated** into the NixOS configuration
flow:

```nix
# In nixos-configuration-helpers.nix
lib'.nixosSystem {
  modules = [
    # ... feature modules ...
    home-manager'.nixosModules.home-manager  # NixOS module integration
    {
      home-manager.users = lib'.mapAttrs makeHomeConfig enabledUsers;
    }
  ];
}
```

**Key characteristics:**

1. Home-manager runs as a NixOS module
1. User configurations are built within the system configuration
1. Uses `osConfig` to access system settings (e.g.,
   `osConfig.system.stateVersion`)
1. Tight coupling to NixOS-specific options

### Current Feature System

Features can provide modules for different contexts:

```nix
{
  features.example = {
    name = "example";

    # System-level module (NixOS-specific currently)
    nixos = { config, pkgs, ... }: { ... };

    # Home-manager module (platform-agnostic)
    home = { config, pkgs, ... }: { ... };

    # Dependencies and exclusions
    requires = ["dependency-feature"];
    excludes = ["conflicting-feature"];
  };
}
```

## Requirements

### 1. NixOS (Current - Must Maintain)

- System configuration via `nixosSystem`
- Home-manager integrated as NixOS module
- Access to `osConfig` from home-manager

### 2. nix-darwin (New Requirement)

- System configuration via `darwinSystem`
- Home-manager integrated as darwin module
- Access to `darwinConfig` from home-manager
- Darwin-specific features and modules

### 3. Standalone Home Manager (Future)

- Direct home-manager configuration
- No OS config integration
- User-level only (no system modules)

## Proposed Architecture

### Phase 1: Generalize the Library

#### 1.1: Rename and Extend Module Types

**New Feature Module Type System:**

```nix
{
  features.example = {
    name = "example";

    # Cross-platform system modules (works on both NixOS and darwin)
    system = { config, pkgs, ... }: { ... };

    # Linux-specific system modules (NixOS only)
    linux = { config, pkgs, ... }: { ... };

    # Darwin-specific system modules (macOS only)
    darwin = { config, pkgs, ... }: { ... };

    # Home-manager modules (works on all platforms)
    home = { config, pkgs, ... }: { ... };

    requires = ["dependency"];
    excludes = ["conflict"];
  };
}
```

**Backward Compatibility:**

- Existing `nixos` key will be treated as `system` + `linux` merged
- Or we can provide a migration path to split them explicitly

#### 1.2: Platform Detection from System Architecture

**No separate `platform` field needed** - detect from `system`:

```nix
# Detect platform from system architecture
isPlatformDarwin = system: lib.hasSuffix "-darwin" system;
isPlatformLinux = system: lib.hasSuffix "-linux" system;

# Use in builders
platform = if isPlatformDarwin hostOptions.system then "darwin"
           else if isPlatformLinux hostOptions.system then "nixos"
           else throw "Unsupported system: ${hostOptions.system}";
```

#### 1.3: Rename nixosConfiguration → systemConfiguration

```nix
# modules/flake-parts/meta/host-options.nix
{
  options.hosts = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        system = mkOption {
          type = types.enum [
            "aarch64-linux"
            "x86_64-linux"
            "aarch64-darwin"  # Already added
            "x86_64-darwin"   # NEW
          ];
          # ... existing config ...
        };

        # NEW: Unified system configuration
        systemConfiguration = mkOption {
          type = types.deferredModule;
          default = { };
          description = "Host-specific system module configuration";
        };

        # DEPRECATED: Backward compatibility
        nixosConfiguration = mkOption {
          type = types.deferredModule;
          default = { };
          description = "Deprecated: Use systemConfiguration instead";
        };

        # ... rest of options ...
      };
    });
  };
}
```

#### 1.4: Refactor Module Collection

Update module collectors to support the new type system:

```nix
# Section 1: Module Collection Utilities (UPDATED)

collectTypedModules =
  type: lib.foldr (v: acc: if v.${type} or null != null then acc ++ [ v.${type} ] else acc) [ ];

# Collect cross-platform system modules
collectSystemModules = collectTypedModules "system";

# Collect platform-specific system modules
collectLinuxModules = collectTypedModules "linux";
collectDarwinModules = collectTypedModules "darwin";

# Collect home-manager modules
collectHomeModules = collectTypedModules "home";

# NEW: Collect all applicable system modules for a platform
collectPlatformSystemModules = features: system:
  let
    isDarwin = lib.hasSuffix "-darwin" system;
    isLinux = lib.hasSuffix "-linux" system;

    # Cross-platform modules (always included)
    systemModules = collectSystemModules features;

    # Platform-specific modules
    platformModules =
      if isDarwin then collectDarwinModules features
      else if isLinux then collectLinuxModules features
      else throw "Unsupported system: ${system}";
  in
  systemModules ++ platformModules;

# DEPRECATED: Backward compatibility for existing nixos key
# Treats 'nixos' as 'system' + 'linux' combined
collectNixosModules = features:
  let
    # Legacy nixos modules (will be migrated to system/linux)
    legacyModules = collectTypedModules "nixos" features;
  in
  legacyModules;
```

### Phase 2: Extract Platform-Agnostic Logic

Create shared builders that work across platforms:

```nix
# ============================================================================
# SECTION 4A: Platform-Agnostic User Configuration
# ============================================================================
# This logic works for NixOS, darwin, and standalone home-manager

# Build home-manager imports for a user (no platform-specific integration)
makeHomeModules = {
  username,
  environment,
  hostOptions,
  allHostFeatures,
  lib',
  platform ? null,  # Optional: "nixos", "darwin", or null for standalone
}:
  let
    # ... existing makeHomeConfig logic (unchanged) ...
    # This is already platform-agnostic!
  in
  {
    imports = coreHomeModules ++ nonCoreHostHomeModules ++ userHomeModules ++ userConfigs;
  };

# ============================================================================
# SECTION 4B: Platform-Specific Home Manager Integration
# ============================================================================

# NixOS integration module
makeNixosHomeManagerModule = {
  enabledUsers,
  environment,
  hostOptions,
  allHostFeatures,
  lib',
  home-manager',
}:
  {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = ".hm-backup";

      extraSpecialArgs = {
        inherit inputs environment hostOptions activeFeatures pkgs;
        hasGlobalPkgs = true;
      };

      sharedModules = [
        ({ osConfig, ... }: {
          home.stateVersion = osConfig.system.stateVersion;
          systemd.user.startServices = "sd-switch";
          programs.home-manager.enable = true;
        })
      ];

      users = lib'.mapAttrs (username: _userSpec:
        makeHomeModules {
          inherit username environment hostOptions allHostFeatures lib';
          platform = "nixos";
        }
      ) enabledUsers;
    };
  };

# Darwin integration module
makeDarwinHomeManagerModule = {
  enabledUsers,
  environment,
  hostOptions,
  allHostFeatures,
  lib',
  home-manager',
}:
  {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = ".hm-backup";

      extraSpecialArgs = {
        inherit inputs environment hostOptions activeFeatures pkgs;
        hasGlobalPkgs = true;
      };

      sharedModules = [
        ({ darwinConfig, ... }: {
          home.stateVersion = darwinConfig.system.stateVersion;
          programs.home-manager.enable = true;
        })
      ];

      users = lib'.mapAttrs (username: _userSpec:
        makeHomeModules {
          inherit username environment hostOptions allHostFeatures lib';
          platform = "darwin";
        }
      ) enabledUsers;
    };
  };
```

### Phase 3: Create Platform-Specific Builders

#### 3.1: Extract Common Host Logic

```nix
# ============================================================================
# SECTION 5A: Shared Host Configuration Logic
# ============================================================================

# Resolve features, users, and prepare arguments (platform-agnostic)
prepareHostContext = {
  hostOptions,
  overrideRoles ? null,
  inputs,
  config,
}:
  let
    # Package set selection (works for both nixos and darwin)
    useUnstable = hostOptions.unstable or false;
    pkgs' = if useUnstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
    lib' = pkgs'.lib;
    home-manager' = if useUnstable then inputs.home-manager-unstable else inputs.home-manager;

    # Environment and roles
    environment = config.environments.${hostOptions.environment};
    effectiveRoles = if overrideRoles != null then overrideRoles else hostOptions.roles;

    # Feature resolution (platform-agnostic)
    allHostFeatures = getModulesForFeatures {
      hostRoles = effectiveRoles;
      hostFeatures = hostOptions.features or [ ];
      hostExclusions = hostOptions.exclude-features or [ ];
    };

    activeFeatures = lib.unique (map (f: f.name) allHostFeatures);

    # User computation (platform-agnostic)
    enabledUsers = let
      environmentUserNames = builtins.attrNames (environment.users or { });
      hostUserNames = builtins.attrNames (hostOptions.users or { });
      enabledUserNames = lib'.unique (environmentUserNames ++ hostUserNames);
      allUsers = lib'.filterAttrs (userName: _: lib'.elem userName enabledUserNames) environment.users;
    in
      lib'.filterAttrs (_userName: user: user.enableUnixAccount or false) allUsers;
  in
  {
    inherit
      pkgs'
      lib'
      home-manager'
      environment
      effectiveRoles
      allHostFeatures
      activeFeatures
      enabledUsers
      ;
  };
```

#### 3.2: NixOS Builder

```nix
# ============================================================================
# SECTION 5B: NixOS Host Builder
# ============================================================================

mkNixosHost = {
  hostOptions,
  overrideRoles ? null,
  skipHomeManager ? false,
  skipHostConfig ? false,
  extraModules ? [ ],
}:
  withSystem hostOptions.system ({ system, ... }:
    let
      ctx = prepareHostContext {
        inherit hostOptions overrideRoles inputs config;
      };

      # Collect all applicable system modules for Linux
      systemModules = collectPlatformSystemModules ctx.allHostFeatures system;

      # Get system configuration (backward compatible)
      systemConfig = hostOptions.systemConfiguration or hostOptions.nixosConfiguration;
    in
    ctx.lib'.nixosSystem {
      inherit system;

      specialArgs = {
        inherit (ctx) pkgs' activeFeatures;
        inherit inputs hostOptions;
        inherit (config.flake) nodes;
        inherit (ctx) environment;
        users = ctx.enabledUsers;
        lib = ctx.lib';
      };

      modules = systemModules
        ++ [
          ctx.pkgs'.nixosModules.notDetected
          ctx.home-manager'.nixosModules.home-manager
        ]
        ++ (if skipHomeManager then [ ] else [
          (makeNixosHomeManagerModule {
            inherit (ctx) enabledUsers environment hostOptions allHostFeatures lib' home-manager';
          })
        ])
        ++ hostOptions.extra_modules
        ++ extraModules
        ++ (if skipHostConfig then [ ] else [ systemConfig ]);
    }
  );
```

#### 3.3: Darwin Builder

```nix
# ============================================================================
# SECTION 5C: Darwin Host Builder
# ============================================================================

mkDarwinHost = {
  hostOptions,
  overrideRoles ? null,
  skipHomeManager ? false,
  skipHostConfig ? false,
  extraModules ? [ ],
}:
  withSystem hostOptions.system ({ system, ... }:
    let
      ctx = prepareHostContext {
        inherit hostOptions overrideRoles inputs config;
      };

      # Collect all applicable system modules for Darwin
      systemModules = collectPlatformSystemModules ctx.allHostFeatures system;

      # Get system configuration (backward compatible)
      systemConfig = hostOptions.systemConfiguration or hostOptions.nixosConfiguration;
    in
    inputs.darwin.lib.darwinSystem {
      inherit system;

      specialArgs = {
        inherit (ctx) pkgs' activeFeatures;
        inherit inputs hostOptions;
        inherit (config.flake) nodes;
        inherit (ctx) environment;
        users = ctx.enabledUsers;
        lib = ctx.lib';
      };

      modules = systemModules
        ++ [
          ctx.home-manager'.darwinModules.home-manager
        ]
        ++ (if skipHomeManager then [ ] else [
          (makeDarwinHomeManagerModule {
            inherit (ctx) enabledUsers environment hostOptions allHostFeatures lib' home-manager';
          })
        ])
        ++ hostOptions.extra_modules
        ++ extraModules
        ++ (if skipHostConfig then [ ] else [ systemConfig ]);
    }
  );
```

#### 3.4: Unified Builder (Smart Dispatch)

```nix
# ============================================================================
# SECTION 6: Public API Functions
# ============================================================================

# Smart host builder that dispatches based on system architecture
mkHost = name: hostOptions:
  let
    isDarwin = lib.hasSuffix "-darwin" hostOptions.system;
    isLinux = lib.hasSuffix "-linux" hostOptions.system;
  in
  if isLinux then
    mkNixosHost {
      inherit hostOptions;
      overrideRoles = null;
      skipHomeManager = false;
      skipHostConfig = false;
      extraModules = [ ];
    }
  else if isDarwin then
    mkDarwinHost {
      inherit hostOptions;
      overrideRoles = null;
      skipHomeManager = false;
      skipHostConfig = false;
      extraModules = [ ];
    }
  else
    throw "Unsupported system architecture: ${hostOptions.system}";

# Keep existing specialized builders
mkHostKexec = name: hostOptions: /* ... existing implementation ... */;
```

### Phase 4: Standalone Home Manager (Future)

For standalone home-manager configurations (no OS integration):

```nix
# ============================================================================
# SECTION 5D: Standalone Home Manager Builder (Future)
# ============================================================================

mkStandaloneHome = {
  username,
  environment,
  features ? [ ],
  excludeFeatures ? [ ],
  extraConfig ? { },
}:
  let
    # Simplified context without host options
    allUserFeatures = getModulesForFeatures {
      hostRoles = null;
      hostFeatures = features;
      hostExclusions = excludeFeatures;
    };

    # Build home configuration without OS integration
    homeModules = makeHomeModules {
      inherit username environment lib';
      hostOptions = { users = { }; };  # Empty host
      allHostFeatures = [ ];  # No host features
      platform = null;  # Standalone
    };
  in
  inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    modules = [ homeModules extraConfig ];
  };
```

## Migration Path

### Step 1: Backward Compatibility

Add compatibility shims in the library:

```nix
# In module collectors - support legacy 'nixos' key
collectNixosModules = features:
  let
    # Treat legacy 'nixos' modules as system+linux combined
    legacyModules = collectTypedModules "nixos" features;
  in
  legacyModules;

# In builders - support old nixosConfiguration name
systemConfig = hostOptions.systemConfiguration
  or hostOptions.nixosConfiguration  # Backward compat
  or { };
```

### Step 2: Gradual Feature Migration

Features can be migrated from `nixos` → `system` + `linux`:

```nix
# Before (NixOS only, legacy)
features.ssh = {
  nixos = { ... };  # Works on NixOS only
  home = { ... };
};

# Option 1: Cross-platform migration (works on both NixOS and Darwin)
features.ssh = {
  system = { ... };  # Works on both platforms!
  home = { ... };
};

# Option 2: Platform-specific migration
features.ssh = {
  system = { ... };   # Shared config for both
  linux = { ... };    # Linux-specific additions
  darwin = { ... };   # Darwin-specific additions
  home = { ... };
};

# Example: GPU feature (Linux-only)
features.gpu-nvidia = {
  linux = { ... };    # Only makes sense on Linux
  home = { ... };
};
```

### Step 3: Host Migration

Hosts automatically detect platform from system architecture:

```nix
# NixOS host (no changes needed!)
hosts.myhost = {
  system = "x86_64-linux";  # Auto-detects Linux/NixOS
  nixosConfiguration = ./default.nix;  # Still works (deprecated)
};

# NixOS host (migrated)
hosts.myhost = {
  system = "x86_64-linux";
  systemConfiguration = ./default.nix;  # New name
};

# Darwin host (new)
hosts.macbook = {
  system = "aarch64-darwin";  # Auto-detects Darwin/macOS
  systemConfiguration = ./default.nix;
  roles = ["laptop" "dev"];
};
```

## Benefits

### 1. **Code Reuse**

- Feature resolution logic is platform-agnostic
- User configuration logic is shared
- Only platform integration differs

### 2. **Maintainability**

- Clear separation of concerns
- Platform-specific code is isolated
- Easy to add new platforms

### 3. **Flexibility**

- Supports NixOS, darwin, and standalone HM
- Features can target specific platforms
- Gradual migration path

### 4. **Consistency**

- Same feature system across platforms
- Unified user management
- Consistent dependency resolution

## File Structure

Suggested reorganization:

```
modules/lib/
├── system-configuration-helpers.nix  # Renamed from nixos-configuration-helpers.nix
│   ├── Section 1: Module Collection (nixos, darwin, home)
│   ├── Section 2: Feature Dependency Resolution (unchanged)
│   ├── Section 3: Feature Aggregation (unchanged)
│   ├── Section 4A: Platform-Agnostic User Config
│   ├── Section 4B: Platform-Specific HM Integration
│   ├── Section 5A: Shared Host Context
│   ├── Section 5B: NixOS Builder
│   ├── Section 5C: Darwin Builder
│   ├── Section 5D: Standalone HM Builder (future)
│   └── Section 6: Public API
└── system-configuration-helpers.md  # Updated docs
```

## Testing Strategy

1. **Backward Compatibility Tests**
   - All existing NixOS hosts build unchanged
   - Legacy `nixos` module key still works
   - Legacy `nixosConfiguration` option still works

1. **Darwin Tests**
   - Create sample darwin host with `system = "aarch64-darwin"`
   - Test feature resolution with `system` and `darwin` modules
   - Verify home-manager integration via `darwinModules.home-manager`

1. **Feature Module Type Tests**
   - Features with only `system` work on both platforms
   - Features with only `linux` work on Linux/NixOS only
   - Features with only `darwin` work on Darwin/macOS only
   - Features with `home` work on all platforms
   - Features with combined `system` + `linux` + `darwin` work correctly on
     respective platforms

## Open Questions

1. **How to migrate existing features with `nixos` key?**
   - **Answer**: Support both during migration. `nixos` treated as legacy
     fallback. New features use `system`/`linux`/`darwin`.
   - **Migration strategy**: Create a deprecation warning helper that alerts
     when `nixos` key is used.

1. **Should we automatically merge `nixos` modules into `system` + `linux`?**
   - **Proposal**: During transition, `collectNixosModules` includes both legacy
     `nixos` and new `system`+`linux` modules.
   - After migration, remove `nixos` support entirely.

1. **How do darwin-specific options map to NixOS equivalents?**
   - Investigation needed: darwin module system structure
   - May need platform-specific shims for common patterns (e.g., systemd vs
     launchd)
   - Cross-platform features should use abstractions where possible

1. **Should the home-manager core feature be split by platform?**
   - Current: `modules/core/home-manager/default.nix` has NixOS-specific config
   - **Proposal**: Extract to platform-specific sections:
     ```nix
     features.home-manager = {
       system = { /* shared config */ };
       linux = { /* systemd user services */ };
       darwin = { /* launchd user agents */ };
     };
     ```

1. **How to handle features that don't make sense cross-platform?**
   - Use only `linux` or `darwin` keys (not `system`)
   - Examples: `gpu-nvidia` (Linux-only), `touchid` (Darwin-only)
   - No runtime checks needed - module won't be collected for incompatible
     platforms

## Implementation Plan

### Phase 1: Add Module Type Support (No Breaking Changes)

**Goal**: Add `system`, `linux`, `darwin` module types while maintaining
backward compatibility.

**Changes**:

1. Add `collectSystemModules`, `collectLinuxModules`, `collectDarwinModules` to
   Section 1
1. Add `collectPlatformSystemModules` that intelligently selects based on system
   architecture
1. Keep `collectNixosModules` for backward compatibility (collects legacy
   `nixos` modules)
1. Update documentation

**Test**: All existing NixOS hosts build unchanged.

### Phase 2: Add Darwin Builder

**Goal**: Create darwin host builder that uses the new module collection.

**Changes**:

1. Add `nix-darwin` to flake inputs
1. Add `x86_64-darwin` to system enum in host-options.nix
1. Implement `mkDarwinHost` in Section 5C
1. Implement `makeDarwinHomeManagerModule` in Section 4B
1. Update `mkHost` to dispatch based on system architecture (Section 6)

**Test**: Create a sample darwin host and verify it builds.

### Phase 3: Rename nixosConfiguration → systemConfiguration

**Goal**: Unified naming for system configuration across platforms.

**Changes**:

1. Add `systemConfiguration` option to host-options.nix
1. Keep `nixosConfiguration` as deprecated alias with fallback
1. Update all builders to use `systemConfiguration or nixosConfiguration`

**Test**: Hosts using old name still work, new hosts can use new name.

### Phase 4: Feature Migration (Gradual)

**Goal**: Migrate features from `nixos` → `system`/`linux`/`darwin`.

**Strategy**:

- **Cross-platform features** (ssh, nix, home-manager): Migrate `nixos` →
  `system`
- **Linux-only features** (gpu-nvidia, systemd services): Migrate `nixos` →
  `linux`
- **New darwin features**: Add `darwin` modules as needed
- **Platform-specific additions**: Use both `system` + `linux`/`darwin` where
  needed

**Test**: Each migrated feature builds on both NixOS and Darwin (if applicable).

### Phase 5: Update Documentation and Examples

**Goal**: Clear guidance for multi-platform configuration.

**Changes**:

1. Update feature documentation to explain module types
1. Add darwin host examples
1. Document migration path from `nixos` to new module types
1. Update CLAUDE.md with multi-platform guidance

---

## Next Steps

**Immediate**:

1. ✅ Review and approve this revised proposal
1. Add `nix-darwin` to flake inputs
1. Implement Phase 1 (module type support)
1. Add `x86_64-darwin` to system enum (already done: `aarch64-darwin`)

**Short-term**: 5. Implement Phase 2 (darwin builder) 6. Create a test darwin
host to validate 7. Implement Phase 3 (rename systemConfiguration)

**Long-term**: 8. Gradually migrate features (Phase 4) 9. Update all
documentation (Phase 5) 10. Consider standalone home-manager support (future)

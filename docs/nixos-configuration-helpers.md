# NixOS Configuration Helpers Library

## Overview

This library provides the core functionality for building NixOS system configurations with a feature-based architecture. It manages:

- Feature aggregation from roles and direct assignments
- Transitive dependency resolution with exclusion handling
- Home Manager user configuration synthesis
- Package set selection (stable vs unstable)
- Specialized builds (standard hosts and kexec installers)

## Architecture

The library is organized into 6 logical sections:

### 1. Module Collection Utilities

**Purpose**: Extract typed modules (nixos/home) from feature definitions

**Functions**:
- `collectTypedModules`: Generic collector for modules of a specific type
- `collectNixosModules`: Extracts NixOS system modules from features
- `collectHomeModules`: Extracts Home Manager modules from features

**Example**:
```nix
# Given features with structure:
features = [
  { name = "foo"; nixos = ./nixos-module.nix; home = ./home-module.nix; }
  { name = "bar"; nixos = ./bar-nixos.nix; }
]

collectNixosModules features  # => [ ./nixos-module.nix ./bar-nixos.nix ]
collectHomeModules features   # => [ ./home-module.nix ]
```

### 2. Feature Dependency Resolution

**Purpose**: Resolve transitive dependencies between features while respecting exclusions

**Function**: `collectRequires`

**Algorithm**:
1. Perform depth-first traversal starting from root features
2. Skip features that are excluded or already visited
3. Accumulate exclusions as tree is traversed
4. Filter dependencies by accumulated exclusions
5. Recursively process dependencies
6. Post-process to remove any features excluded by dependencies
7. Remove root features from result (they're already included elsewhere)

**Flow Diagram**:
```
Input: features (all available), roots (starting features)
  │
  ├─> Collect initial exclusions from roots
  │
  ├─> Traverse dependency tree (DFS):
  │   ├─> Current feature excluded? → Skip
  │   ├─> Already visited? → Skip
  │   ├─> Add feature's exclusions to running set
  │   ├─> Filter dependencies by exclusions
  │   └─> Recurse on dependencies → Add current
  │
  ├─> Gather ALL exclusions from entire tree
  │
  └─> Filter out excluded features and roots
      │
      └─> Return: Dependencies only
```

**Example**:
```nix
# Given:
features = {
  A = { requires = ["B" "C"]; excludes = ["D"]; };
  B = { requires = ["E"]; };
  C = { excludes = ["F"]; };
  D = { }; # Will be excluded
  E = { };
  F = { }; # Will be excluded
};

collectRequires features [features.A]
# => [features.B, features.C, features.E]
# Note: A is not in result (it's a root)
#       D is excluded by A
#       E is included (dependency of B)
#       F is excluded by C
```

### 3. Feature Aggregation from Roles

**Purpose**: Build the complete feature set from role definitions

**Functions**:
- `getFeaturesForRoles`: Aggregate feature names from core + additional roles
- `getModulesForFeatures`: Resolve complete feature set with dependencies

**Flow**:
```
Input: hostRoles, hostFeatures, hostExclusions
  │
  ├─> Step 1: Aggregate feature names
  │   ├─> Get core role features
  │   ├─> Get additional role features
  │   └─> Merge with direct host features
  │
  ├─> Step 2: Convert names to feature modules
  │
  ├─> Step 3: Collect and merge exclusions
  │   ├─> From feature definitions
  │   └─> From host-level exclusions
  │
  ├─> Step 4: Filter out excluded features
  │
  ├─> Step 5: Resolve transitive dependencies
  │   └─> collectRequires(...)
  │
  └─> Step 6: Combine roots + dependencies
      │
      └─> Return: Complete feature set
```

**Example**:
```nix
getModulesForFeatures {
  hostRoles = ["server"];           # Brings features: ["ssh", "monitoring"]
  hostFeatures = ["docker"];        # Direct feature assignment
  hostExclusions = ["telemetry"];   # Exclude this feature
}
# Result includes: ssh, monitoring, docker + their dependencies
# excluding any feature named "telemetry"
```

### 4. Home Manager User Configuration

**Purpose**: Build home-manager configuration for individual users

**Function**: `makeHomeConfig`

**Inputs**:
- `username`: User account name
- `environment`: Environment configuration with user specs
- `hostOptions`: Host configuration
- `allHostFeatures`: Resolved host features
- `lib'`: Nix library (stable or unstable)

**Feature Inheritance Logic**:
```
For each user:
  ├─> Core host features: ALWAYS included
  │
  ├─> Non-core host features: Conditional
  │   └─> Included if inheritHostFeatures = true
  │
  └─> User-specific features:
      ├─> Baseline features (from user baseline)
      ├─> Environment features (from environment.users)
      └─> Host-specific features (from hostOptions.users)
```

**Exclusion Handling**:
- Host exclusions are collected from all host features
- User exclusions are collected from user-specific features
- Both are merged and applied to filter features
- Core features are filtered separately to ensure they're not excluded

**Flow Diagram**:
```
Input: username, environment, hostOptions, allHostFeatures
  │
  ├─> Get user specifications (env + host)
  │
  ├─> Collect exclusions
  │   ├─> From host features
  │   └─> From user features
  │
  ├─> Aggregate user feature names
  │   ├─> Baseline features
  │   ├─> Environment features
  │   └─> Host features
  │
  ├─> Filter and resolve user features
  │   ├─> Apply exclusions
  │   └─> Resolve dependencies
  │
  ├─> Split host features
  │   ├─> Core (always included)
  │   └─> Non-core (conditional on inheritHostFeatures)
  │
  ├─> Collect home modules from:
  │   ├─> Core host features
  │   ├─> Non-core host features (if inheriting)
  │   └─> User features
  │
  └─> Merge with user configuration overrides
      │
      └─> Return: Home Manager imports list
```

### 5. Host Configuration Builder

**Purpose**: Core logic for building NixOS system configurations

**Function**: `mkHostCommon`

**Parameters**:
- `hostOptions`: Host-specific configuration options
- `overrideRoles`: Optional role override (for specialized builds)
- `skipHomeManager`: Skip home-manager configuration
- `skipHostConfig`: Skip host-specific configuration file
- `extraModules`: Additional NixOS modules to include

**Build Process**:
```
1. Select package set (stable vs unstable)
   ├─> Based on hostOptions.unstable
   └─> Determines: pkgs', lib', home-manager'

2. Load environment configuration
   └─> From config.flake.environments.${hostOptions.environment}

3. Determine effective roles
   └─> Use override if provided, else hostOptions.roles

4. Resolve features with dependencies
   └─> getModulesForFeatures(...)

5. Extract feature names and NixOS modules
   └─> For specialArgs and module imports

6. Compute enabled users
   └─> Filter by enableUnixAccount = true

7. Build nixosSystem with:
   ├─> specialArgs (pkgs', inputs, hostOptions, environment, users, etc.)
   └─> modules:
       ├─> Feature NixOS modules
       ├─> External modules (nixosModules.notDetected, home-manager)
       ├─> Home Manager user configurations (if not skipped)
       ├─> Host extra_modules
       ├─> Function extraModules
       └─> Host nixosConfiguration (if not skipped)
```

### 6. Public API Functions

**Functions**:
- `mkHost`: Build standard NixOS host configuration
- `mkHostKexec`: Build minimal kexec installer variant

#### mkHost

Standard host configuration builder.

**Usage**:
```nix
mkHost "hostname" {
  system = "x86_64-linux";
  unstable = false;
  environment = "prod";
  roles = ["server" "kubernetes"];
  features = ["docker" "monitoring"];
  exclude-features = ["bluetooth"];
  users = { ... };
  extra_modules = [ ... ];
  nixosConfiguration = ./hosts/hostname/default.nix;
}
```

#### mkHostKexec

Builds a minimal network installer variant of a host.

**Differences from mkHost**:
- Uses only "kexec" role (minimal feature set)
- Adds installer-specific exclusions
- Clears all host-specific features
- Skips home-manager configuration
- Skips host-specific hardware configuration
- Forces hostname to installer-specific name

**Excluded Features**:
- `network-boot`: Host-specific network boot settings
- `facter`: Hardware detection not needed for installer
- `systemd-boot`: Bootloader not needed for installer
- `avahi`: Service discovery not needed for installer
- `power-mgmt`: Power management not needed for installer
- `ssd`: SSD optimizations not needed for installer

**Usage**:
```nix
mkHostKexec "hostname-installer" hostOptions
# Creates: hostname-installer (minimal installer)
# From: hostOptions (standard host config)
```

## Key Concepts

### Features

Features are composable units of system configuration that can:
- Provide NixOS system modules (`nixos` attribute)
- Provide Home Manager modules (`home` attribute)
- Declare dependencies (`requires` attribute)
- Declare exclusions (`excludes` attribute)

### Roles

Roles are collections of features that define a system profile:
- `core`: Base features for all systems
- `server`: Server-specific features
- `workstation`: Desktop workstation features
- `laptop`: Laptop-specific features
- `kexec`: Minimal installer features

### Exclusions

Exclusions allow features to prevent other features from being included:
- Exclusions propagate through the dependency tree
- Excluded features are filtered at multiple stages
- Host-level exclusions override feature-level inclusions

### Package Set Selection

Hosts can use either stable or unstable nixpkgs:
- `hostOptions.unstable = false`: Use stable nixpkgs (default)
- `hostOptions.unstable = true`: Use nixpkgs-unstable
- This affects: pkgs, lib, and home-manager versions

## Maintenance Guidelines

### Adding New Functionality

When extending this library:

1. **Identify the appropriate section** for your addition
2. **Add clear comments** explaining the purpose and algorithm
3. **Update this documentation** with examples and flow diagrams
4. **Test with multiple hosts** to ensure no regressions

### Common Pitfalls

1. **Exclusion ordering**: Exclusions must be collected and applied at each stage
2. **Root removal**: Dependency resolution should not include root features in results
3. **Library consistency**: Use lib' (versioned) instead of lib in host configurations
4. **Feature deduplication**: Always use lib.unique when merging feature lists

### Performance Considerations

- Feature resolution is memoized by Nix's lazy evaluation
- Avoid redundant feature lookups by passing resolved features through functions
- Use filter before map when possible to reduce evaluation load

## Examples

### Simple Host with Role

```nix
mkHost "webserver" {
  system = "x86_64-linux";
  roles = ["server"];
  environment = "prod";
  nixosConfiguration = ./hosts/webserver/default.nix;
}
```

### Host with Custom Features

```nix
mkHost "devbox" {
  system = "x86_64-linux";
  roles = ["workstation"];
  features = ["docker" "vscode" "rust-dev"];
  exclude-features = ["games"];
  environment = "dev";
  nixosConfiguration = ./hosts/devbox/default.nix;
}
```

### Unstable Host

```nix
mkHost "bleeding-edge" {
  system = "x86_64-linux";
  unstable = true;  # Use nixpkgs-unstable
  roles = ["workstation"];
  environment = "dev";
  nixosConfiguration = ./hosts/bleeding-edge/default.nix;
}
```

### Kexec Installer

```nix
mkHostKexec "server-01-installer" config.flake.hosts.server-01
# Creates minimal installer based on server-01 configuration
```

## Testing

Verify library functionality:

```bash
# Check library exports
nix eval .#lib.nixos-configuration-helpers --apply 'builtins.attrNames'

# Verify host configuration
nix eval .#nixosConfigurations.hostname.config.system.name

# Build a host
nix build .#nixosConfigurations.hostname.config.system.build.toplevel
```

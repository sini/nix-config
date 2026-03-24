# Feature Settings Implementation Plan

## Overview

Add typed, per-feature settings to the feature system. Currently features are
binary (on/off) with no way to pass configuration parameters. This adds an
optional `settings` attribute to each feature, generates a unified type from all
features' settings declarations, and merges values through `lib.evalModules`
with native priority.

The design is directly analogous to how `kubernetes.services.<name>.options`
works in `modules/flake-parts/kubernetes/service-helpers.nix`.

## Design Decisions

1. **Settings declaration**: Each feature optionally declares `settings` with
   typed `mkOption` declarations (like k8s service `options`)

1. **Dynamic type generation**: Generate `featureSettingsType` from all
   features' settings declarations (like `serviceOptions` in
   service-helpers.nix). Features without settings get no entry.

1. **Merging via NixOS module system**: Use `lib.evalModules` with native
   priority instead of manual coalesce:
   - Feature defaults: from `mkOption { default = ...; }` (lowest)
   - Environment `settings`: wrapped in `lib.mkDefault` (middle)
   - Host `settings`: plain values (high)
   - User `settings`: plain values, home modules only (highest)
   - `lib.mkForce` available at any level

1. **Unified `settings` specialArg**: Passed as
   `settings.<featureName>.<option>` so features can read each other's settings.

1. **User-level settings for home modules only**: System modules see feature →
   env → host. Home modules see feature → env → host → user.

1. **Self-contained in `flake-parts/features/`**: Type generator, resolution
   function, and helpers all live in the features directory.

## Phase 1: Feature Settings Infrastructure

### 1a. Add `settings` to `featureSubmodule`

**File:** `modules/flake-parts/features/helpers.nix`

Add to `featureSubmodule` options (alongside `requires`, `excludes`, etc.):

```nix
settings = mkOption {
  type = types.lazyAttrsOf types.raw;
  default = { };
  description = ''
    Option declarations for per-feature configuration.
    Should contain ONLY option declarations (mkOption), no config assignments.
  '';
};
```

Mirrors `serviceSubmodule.options` in `service-helpers.nix:34-41`.

### 1b. Create `mkFeatureSettingsOpt`

**File:** `modules/flake-parts/features/helpers.nix`

Dynamic type generator analogous to `serviceOptions`
(`service-helpers.nix:137-157`):

```nix
mkFeatureSettingsOpt = featuresConfig: description: mkOption {
  type = types.submodule {
    options = lib.mapAttrs (name: feature:
      mkOption {
        type =
          if feature.settings or { } != { } then
            types.submodule { options = feature.settings; }
          else
            types.attrs;
        default = { };
        description = "Settings for the ${name} feature";
      }
    ) (lib.filterAttrs (_: f: f.settings or { } != { }) featuresConfig);
  };
  default = { };
  inherit description;
};
```

Only features with non-empty `settings` get an entry in the generated type.

### 1c. Create `resolveFeatureSettings`

**File:** `modules/flake-parts/features/helpers.nix`

Uses `lib.evalModules` to merge settings layers with native NixOS priority:

```nix
resolveFeatureSettings =
  { activeFeatureNames, featuresConfig
  , envSettings ? { }, hostSettings ? { }, userSettings ? { }
  }:
  let
    relevantFeatures = lib.filterAttrs
      (name: f: lib.elem name activeFeatureNames && f.settings or { } != { })
      featuresConfig;

    settingsOptions = lib.mapAttrs (name: feature: mkOption {
      type = types.submodule { options = feature.settings; };
      default = { };
    }) relevantFeatures;

    envModule = { lib, ... }: {
      config = lib.mapAttrs (_: value:
        lib.mapAttrs (_: lib.mkDefault) value
      ) (lib.intersectAttrs relevantFeatures envSettings);
    };

    hostModule = { ... }: {
      config = lib.intersectAttrs relevantFeatures hostSettings;
    };

    userModule = { ... }: {
      config = lib.intersectAttrs relevantFeatures userSettings;
    };

    evaluated = lib.evalModules {
      modules = [
        { options = settingsOptions; }
        envModule
        hostModule
        userModule
      ];
    };
  in
  evaluated.config;
```

Replaces the manual `coalesce` pattern used in user resolution.

### 1d. Export from `flake.lib.modules`

**File:** `modules/flake-parts/features/helpers.nix`

Add `mkFeatureSettingsOpt` and `resolveFeatureSettings` to the existing
`flake.lib.modules` exports.

## Phase 2: Wire Settings into Options

### 2a. Environment options

**File:** `modules/flake-parts/environments/options.nix`

Add to environment submodule options:

```nix
settings = self.lib.modules.mkFeatureSettingsOpt config.features
  "Default feature settings for all hosts in this environment";
```

### 2b. Host options

**File:** `modules/flake-parts/hosts/options.nix`

Add to host submodule options (near `extra-features`):

```nix
settings = self.lib.modules.mkFeatureSettingsOpt flakeConfig.features
  "Per-host feature settings (overrides environment defaults)";
```

### 2c. User options

**File:** `modules/flake-parts/users/helpers.nix`

Add `settings` to canonical user type, `mkEnvUsersOpt`, and `mkHostUsersOpt`.
These require passing `featuresConfig` into the helper functions.

For canonical users (`modules/flake-parts/users/options.nix`), add to the
`system` submodule:

```nix
settings = mkOption {
  type = types.attrsOf types.attrs;
  default = { };
  description = "Per-feature settings defaults for this user's home modules";
};
```

### 2d. Thread `settings` through user resolution

**File:** `modules/flake-parts/users/helpers.nix`

In `resolveUser`, pass `settings` through the coalesce chain to the resolved
user object. The actual merge happens later via `resolveFeatureSettings` in
`makeHomeConfig`, not here — we just preserve the raw values.

## Phase 3: Resolve and Pass Settings

### 3a. Resolve system-level settings in `prepareHostContext`

**File:** `modules/flake-parts/hosts/configuration-helpers.nix`

After `activeFeatures` is computed, resolve settings:

```nix
settings = self.lib.modules.resolveFeatureSettings {
  activeFeatureNames = activeFeatures;
  featuresConfig = config.features;
  envSettings = environment.settings or { };
  hostSettings = hostOptions.settings or { };
};
```

### 3b. Add `settings` to `specialArgs`

**File:** `modules/flake-parts/hosts/configuration-helpers.nix`

Add `settings` to the `specialArgs` attrset. This makes it available to all
system-level feature modules (`system`, `linux`, `darwin`).

### 3c. Resolve per-user settings in `makeHomeConfig`

**File:** `modules/flake-parts/hosts/configuration-helpers.nix`

In `makeHomeConfig`, resolve settings with the user layer added. Pass
`environment` and `hostOptions` into `makeHomeConfig` (they're already in scope
in `prepareHostContext`).

Inject the resolved per-user settings into the home module imports via
`_module.args.settings`. This ensures each user gets their own resolved settings
(feature defaults → env → host → user).

Do NOT add `settings` to home-manager `extraSpecialArgs` in
`core/home-manager/default.nix` — per-user settings differ per user, so they
must be injected per-user via `_module.args`.

## Phase 4: Migrate Tailscale

### Why Tailscale

Currently reads `environment` and `host` directly. Would benefit from
configurable loginServer, firewall, and nftables settings.

### 4a. Declare settings

**File:** `modules/core/network/tailscale.nix`

```nix
features.tailscale = {
  settings = {
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    useNftables = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
  # existing system/linux/darwin modules updated to use { settings, ... }
};
```

### 4b. Use settings in modules

Replace hardcoded values with `settings.tailscale.*` references.

### 4c. Verify with overrides

Test environment-level and host-level `settings.tailscale.*` values merge
correctly.

## Dependency Graph

```
Phase 1a (featureSubmodule settings option)
  └─ Phase 1b (mkFeatureSettingsOpt)
     └─ Phase 1c (resolveFeatureSettings)
        └─ Phase 1d (export)
           ├─ Phase 2a (environment options)  ─┐
           ├─ Phase 2b (host options)          ├─ Phase 3a-3c (resolve + wire)
           └─ Phase 2c-2d (user options)      ─┘    └─ Phase 4 (migrate tailscale)
```

## Risks

1. **Infinite recursion**: `mkFeatureSettingsOpt` reads `config.features` to
   build its type. Using `types.lazyAttrsOf` and only accessing
   `feature.settings` (not full feature config) avoids forcing module
   evaluation. Same approach as `serviceOptions` reading
   `config.kubernetes.services`.

1. **evalModules overhead**: Each host + each user triggers an `evalModules`
   call. Settings modules are small (few options per feature), so this is
   negligible vs full NixOS evaluation.

1. **Backward compatibility**: Features without `settings` are unaffected. The
   `settings` specialArg only contains entries for features that declare
   settings.

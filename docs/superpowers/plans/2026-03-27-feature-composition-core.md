# Feature Composition Core Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers-extended-cc:subagent-driven-development (if subagents available) or superpowers-extended-cc:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add providers, unified `includes`, virtual classes, collected providers, and the composition chain to the existing feature system — Phases 1 and 2 of the migration strategy.

**Architecture:** New composition primitives are added to the existing `featureSubmodule` in `helpers.nix` and a new `resolver.nix` alongside it. The old `requires` field and `collectRequires` function are kept as backward-compatible aliases. A new multi-phase resolver handles hierarchical includes, provider collection, and virtual class forwarding. Existing features are untouched; new capabilities are opt-in.

**Tech Stack:** Nix module system (`lib.evalModules`, `types.submodule`, `types.deferredModule`), flake-parts

**Spec:** `docs/superpowers/specs/2026-03-27-feature-composition-core-design.md`

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `modules/flake-parts/features/helpers.nix` | Feature submodule type, module collection utilities, settings | Modify: add `includes`, `provides`, `os`, `homeLinux`, `homeDarwin`, `collectsProviders` options; keep `requires` as alias |
| `modules/flake-parts/features/resolver.nix` | New multi-phase resolver (replaces `collectRequires` internals) | Create |
| `modules/flake-parts/features/compose.nix` | Composition chain (`.wrap/.apply/.eval`) factory | Create |
| `modules/flake-parts/hosts/configuration-helpers.nix` | Host building, module collection, `prepareHostContext` | Modify: use new resolver and virtual class forwarding |
| `modules/flake-parts/features/exports.nix` | Feature extraction as flake outputs | Create |
| `checks/feature-resolver.nix` | Nix-based tests for the resolver | Create |

---

### Task 1: Add Provider Submodule Type and New Options to Feature Submodule

**Goal:** Extend `featureSubmodule` in `helpers.nix` with `includes`, `provides`, `os`, `homeLinux`, `homeDarwin`, and `collectsProviders` options while keeping full backward compatibility.

**Files:**
- Modify: `modules/flake-parts/features/helpers.nix`

**Acceptance Criteria:**
- [ ] `includes` option exists (list of strings, default `[]`)
- [ ] `requires` still works and is treated as alias for `includes` in computed values
- [ ] `provides` option exists as `lazyAttrsOf (submodule providerSubmodule)`
- [ ] Provider submodule has `_id` (auto-injected), `os`, `linux`, `darwin`, `home`, `homeLinux`, `homeDarwin`, `settings`, `user-settings`, `includes`
- [ ] `os` and `homeLinux`/`homeDarwin` class options exist on feature submodule
- [ ] `system` still works (existing features don't break)
- [ ] `collectsProviders` option exists (list of strings, default `[]`)
- [ ] `hasSystemModules` computation includes `os` definitions
- [ ] All existing features build without changes

**Verify:** `nix-flake-build cortex` → builds successfully (no feature changes needed)

**Steps:**

- [ ] **Step 1: Add provider submodule type**

Add above `featureSubmodule` in `helpers.nix`:

```nix
providerSubmodule =
  featureName:
  {
    name,
    ...
  }:
  {
    options = {
      _id = mkOption {
        type = types.str;
        default = "${featureName}/${name}";
        readOnly = true;
        internal = true;
        description = "Compound identity for deduplication.";
      };
      os = mkDeferredModuleOptWithMetadata featureName "provides.${name}.os"
        "OS class (forwards to linux or darwin based on platform)";
      linux = mkDeferredModuleOptWithMetadata featureName "provides.${name}.linux"
        "Linux-specific system module";
      darwin = mkDeferredModuleOptWithMetadata featureName "provides.${name}.darwin"
        "Darwin-specific system module";
      home = mkDeferredModuleOptWithMetadata featureName "provides.${name}.home"
        "Home-manager module";
      homeLinux = mkDeferredModuleOptWithMetadata featureName "provides.${name}.homeLinux"
        "Linux-only home-manager module";
      homeDarwin = mkDeferredModuleOptWithMetadata featureName "provides.${name}.homeDarwin"
        "Darwin-only home-manager module";
      settings = mkOption {
        type = types.lazyAttrsOf types.raw;
        default = { };
        description = "Settings option declarations this provider contributes to its parent feature.";
      };
      user-settings = mkOption {
        type = types.lazyAttrsOf types.raw;
        default = { };
        description = "User-settings option declarations this provider contributes to its parent feature.";
      };
      includes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Additional features/providers this provider depends on.";
      };
    };
  };
```

- [ ] **Step 2: Add new options to featureSubmodule**

Add these options inside `featureSubmodule.options`:

```nix
includes = mkOption {
  type = types.listOf types.str;
  default = [ ];
  description = "Features and providers to include (replaces requires). Accepts feature names ('bat') and provider paths ('bat/alias-as-cat').";
};

provides = mkOption {
  type = types.lazyAttrsOf (types.submodule (providerSubmodule name));
  default = { };
  description = "Named sub-configurations that other features can selectively include.";
};

os = mkDeferredModuleOptWithMetadata name "os"
  "OS class module (forwards to linux or darwin based on host platform)";

homeLinux = mkDeferredModuleOptWithMetadata name "homeLinux"
  "Linux-only home-manager module (forwarded into home on Linux hosts)";

homeDarwin = mkDeferredModuleOptWithMetadata name "homeDarwin"
  "Darwin-only home-manager module (forwarded into home on Darwin hosts)";

collectsProviders = mkOption {
  type = types.listOf types.str;
  default = [ ];
  description = "Provider names to automatically collect from all active features.";
};
```

- [ ] **Step 3: Merge `requires` into `includes` in computed config**

The resolver treats `includes` as the canonical field. For backward compat,
the resolver itself reads BOTH `includes` and `requires` from a feature and
merges them:

```nix
# In the resolver (not in featureSubmodule config):
getFeatureIncludes = feature:
  lib.unique ((feature.includes or []) ++ (feature.requires or []));
```

This approach avoids `mkDefault` priority interactions entirely. Features
that set `requires` still work. Features that set `includes` use the new
field. Features that set both get the union. No silent dropping of values.

- [ ] **Step 4: Update `hasSystemModules` to include `os`**

Modify the `hasSystemModules` computation:

```nix
hasSystemModules =
  let
    hasDefs = opt: builtins.any (d: d.value != { }) opt.definitionsWithLocations;
  in
  hasDefs options.system || hasDefs options.linux || hasDefs options.darwin || hasDefs options.os;
```

- [ ] **Step 5: Build cortex to verify no regressions**

Run: `nix-flake-build cortex`
Expected: Successful build with no changes to any existing feature files.

- [ ] **Step 6: Commit**

```bash
git add modules/flake-parts/features/helpers.nix
git commit -m "feat(features): add provider submodule, includes, virtual classes, collectsProviders options"
```

---

### Task 2: Implement Multi-Phase Resolver

**Goal:** Create the new resolver that handles hierarchical includes (`"bat"` and `"bat/alias-as-cat"`), excludes cascading to providers, collected providers, and deduplication.

**Files:**
- Create: `modules/flake-parts/features/resolver.nix`
- Modify: `modules/flake-parts/features/helpers.nix` (export new resolver functions)

**Acceptance Criteria:**
- [ ] `resolveIncludes` handles plain feature names and `feature/provider` paths
- [ ] Excludes cascade: excluding a feature excludes all its providers
- [ ] Provider-specific excludes work (`"bat/alias-as-cat"`)
- [ ] `collectsProviders` scans active features and includes matching providers
- [ ] Circular includes produce a clear error with the chain path
- [ ] Invalid paths produce clear errors listing available providers
- [ ] Results are deduplicated (features by name, providers by `_id`)
- [ ] Old `computeActiveFeatures` API still works (calls new resolver internally)
- [ ] `getModulesForFeatures` returns both features and active providers

**Verify:** `nix-flake-build cortex` → builds successfully using new resolver

**Steps:**

- [ ] **Step 1: Create resolver.nix with path parsing utilities**

```nix
# modules/flake-parts/features/resolver.nix
{ lib }:
let
  inherit (lib) elem filter head tail;

  # Parse an include path into { type, feature, provider? }
  parseIncludePath = path:
    let parts = lib.splitString "/" path;
    in if builtins.length parts == 1 then
      { type = "feature"; feature = head parts; provider = null; }
    else if builtins.length parts == 2 then
      { type = "provider"; feature = head parts; provider = lib.elemAt parts 1; }
    else
      throw "Invalid include path '${path}': at most one '/' allowed (feature/provider)";

  # Validate a parsed include against featuresConfig
  validateInclude = featuresConfig: parsed:
    let
      featureExists = featuresConfig ? ${parsed.feature};
      feature = featuresConfig.${parsed.feature};
      providerExists = parsed.provider != null ->
        (feature.provides or { }) ? ${parsed.provider};
    in
    if !featureExists then
      throw "feature '${parsed.feature}' not found in includes. Available features: ${
        lib.concatStringsSep ", " (lib.attrNames featuresConfig)
      }"
    else if parsed.provider != null && !providerExists then
      throw "feature '${parsed.feature}' does not provide '${parsed.provider}'. Available: ${
        lib.concatStringsSep ", " (lib.attrNames (feature.provides or { }))
      }"
    else
      parsed;
in
# ... (continued in next steps)
```

- [ ] **Step 2: Implement Phase 1 — explicit resolution with chain tracking**

```nix
  # Phase 1: Resolve explicit includes with cycle detection
  # Returns { features: attrset name→feature, providers: attrset _id→provider, exclusions: list }
  resolveExplicit =
    featuresConfig:
    { initialFeatureNames, initialExclusions ? [] }:
    let
      resolve =
        state: toVisit: chain:
        if toVisit == [] then state
        else
          let
            current = head toVisit;
            remaining = tail toVisit;
            parsed = validateInclude featuresConfig (parseIncludePath current);
            featureName = parsed.feature;
            isFeatureExcluded = elem featureName state.exclusions;
            isProviderExcluded = parsed.provider != null &&
              elem "${featureName}/${parsed.provider}" state.exclusions;
          in
          if isFeatureExcluded || isProviderExcluded then
            resolve state remaining chain
          else if parsed.type == "feature" then
            let
              # Check for cycles FIRST using the in-progress chain
              chainNames = map (p: p.feature) chain;
              _ = if elem featureName chainNames then
                throw "circular include detected: ${
                  lib.concatStringsSep " → " (chainNames ++ [featureName])
                }" else null;
              # Then check if already fully resolved (skip if so)
              isVisited = state.features ? ${featureName};
            in
            if isVisited then
              resolve state remaining chain
            else
              let
                feature = featuresConfig.${featureName};
                newChain = chain ++ [parsed];
                newExclusions = lib.unique (state.exclusions ++ (feature.excludes or []));
                newState = state // {
                  features = state.features // { ${featureName} = feature; };
                  exclusions = newExclusions;
                };
                # Recurse into feature's includes
                featureIncludes = feature.includes or [];
                stateAfterIncludes = resolve newState featureIncludes newChain;
              in
              resolve stateAfterIncludes remaining chain
          else # provider
            let
              providerId = "${featureName}/${parsed.provider}";
              isVisited = state.providers ? ${providerId};
            in
            if isVisited then
              resolve state remaining chain
            else
              let
                # Ensure parent feature is activated
                feature = featuresConfig.${featureName};
                stateWithFeature =
                  if state.features ? ${featureName} then state
                  else state // {
                    features = state.features // { ${featureName} = feature; };
                    exclusions = lib.unique (state.exclusions ++ (feature.excludes or []));
                  };
                provider = feature.provides.${parsed.provider};
                newState = stateWithFeature // {
                  providers = stateWithFeature.providers // { ${providerId} = provider; };
                };
                # Recurse into provider's includes
                providerIncludes = provider.includes or [];
                stateAfterIncludes = resolve newState providerIncludes chain;
              in
              resolve stateAfterIncludes remaining chain;

      initialState = {
        features = {};
        providers = {};
        exclusions = initialExclusions;
      };
      featureNames = initialFeatureNames;
    in
    resolve initialState featureNames [];
```

- [ ] **Step 3: Implement Phase 2 — provider collection**

```nix
  # Phase 2: Collect providers from active features with collectsProviders
  collectProviders = featuresConfig: state:
    let
      collectorsCompleted = {};

      collect = currentState: completedCollectors:
        let
          # Find collectors that haven't run yet
          activeCollectors = lib.filterAttrs (name: feature:
            (feature.collectsProviders or []) != [] &&
            !(completedCollectors ? ${name})
          ) currentState.features;
        in
        if activeCollectors == {} then currentState
        else
          let
            # Gather all provider names to collect
            allCollectorNames = lib.concatLists (
              lib.mapAttrsToList (_: f: f.collectsProviders or []) activeCollectors
            );

            # Scan all active features for matching providers
            newProviders = lib.concatLists (
              map (provName:
                lib.concatLists (
                  lib.mapAttrsToList (featName: feature:
                    let
                      providerId = "${featName}/${provName}";
                      providerExists = (feature.provides or {}) ? ${provName};
                      isExcluded = elem featName currentState.exclusions ||
                        elem providerId currentState.exclusions;
                      alreadyIncluded = currentState.providers ? ${providerId};
                    in
                    if providerExists && !isExcluded && !alreadyIncluded then
                      [{ id = providerId; provider = feature.provides.${provName}; }]
                    else
                      []
                  ) currentState.features
                )
              ) (lib.unique allCollectorNames)
            );

            # Add new providers to state
            stateWithProviders = currentState // {
              providers = currentState.providers // (
                lib.listToAttrs (map (p: lib.nameValuePair p.id p.provider) newProviders)
              );
            };

            # Mark current collectors as completed
            newCompleted = completedCollectors // (
              lib.mapAttrs (_: _: true) activeCollectors
            );

            # Recurse provider includes back through Phase 1
            providerIncludes = lib.concatLists (
              map (p: p.provider.includes or []) newProviders
            );
            stateAfterProviderIncludes =
              if providerIncludes == [] then stateWithProviders
              else
                let
                  newResolved = resolveExplicit featuresConfig {
                    initialFeatureNames = providerIncludes;
                    initialExclusions = stateWithProviders.exclusions;
                  };
                in stateWithProviders // {
                  features = stateWithProviders.features // newResolved.features;
                  providers = stateWithProviders.providers // newResolved.providers;
                  exclusions = lib.unique (stateWithProviders.exclusions ++ newResolved.exclusions);
                };
          in
          # Re-check for newly activated collectors
          collect stateAfterProviderIncludes newCompleted;
    in
    collect state collectorsCompleted;
```

Note: This step will likely need refinement during implementation. The key constraint is: each collector runs at most once.

Add a `lib.warn` for collector names that match zero providers:

```nix
# After scanning, warn for empty collections
_ = lib.forEach allCollectorNames (provName:
  let matched = lib.filter (p: lib.hasSuffix "/${provName}" p.id) newProviders;
  in if matched == [] then
    lib.warn "feature '${collectorName}' collects '${provName}' but no active feature provides it" null
  else null
);
```

- [ ] **Step 4: Implement top-level resolver function**

```nix
  # Top-level resolver: Phase 1 + Phase 2, returns resolved state
  resolveFeatures =
    {
      featuresConfig,
      hostFeatures ? [],
      hostExclusions ? [],
    }:
    let
      coreFeatures = [ "default" ];
      allFeatureNames = lib.unique (coreFeatures ++ hostFeatures);
      phase1 = resolveExplicit featuresConfig {
        initialFeatureNames = allFeatureNames;
        initialExclusions = hostExclusions;
      };
      phase2 = collectProviders featuresConfig phase1;
    in
    phase2;

  # Backward-compatible wrapper: returns list of feature names
  computeActiveFeatures = args:
    let resolved = resolveFeatures args;
    in lib.unique (lib.attrNames resolved.features);
```

- [ ] **Step 5: Export from helpers.nix and wire into lib.modules**

Add to `helpers.nix`:
```nix
resolver = import ./resolver.nix { inherit lib; };
```

Add backward-compatible wrappers that keep the same return types:

```nix
# Returns list of feature names (same as before)
computeActiveFeatures = args:
  let resolved = resolver.resolveFeatures args;
  in lib.unique (lib.attrNames resolved.features);

# Returns list of feature attrsets (same as before) + providers accessible via .providers
getModulesForFeatures = args:
  let resolved = resolver.resolveFeatures args;
  in {
    features = builtins.attrValues resolved.features;
    providers = builtins.attrValues resolved.providers;
    # Backward compat: the old return was a flat list of features
    __functor = _self: _self.features;
  };
```

Note: `__functor` makes the result callable as a list for old callers that
iterate directly. New callers access `.features` and `.providers` explicitly.
Replace the old `computeActiveFeatures`, `getModulesForFeatures`,
`collectRequires` in the exports.

- [ ] **Step 6: Build cortex to verify resolver produces same results as old code**

Run: `nix-flake-build cortex`
Expected: Identical build output — new resolver activated but no features use new capabilities yet.

- [ ] **Step 7: Commit**

```bash
git add modules/flake-parts/features/resolver.nix modules/flake-parts/features/helpers.nix
git commit -m "feat(features): implement multi-phase resolver with includes, providers, and collection"
```

---

### Task 3: Virtual Class Forwarding in Module Collection

**Goal:** Update module collection utilities to handle `os`, `homeLinux`, `homeDarwin` forwarding from both features and providers.

**Files:**
- Modify: `modules/flake-parts/features/helpers.nix` (module collection utilities)
- Modify: `modules/flake-parts/hosts/configuration-helpers.nix` (use new collection)

**Acceptance Criteria:**
- [ ] `collectPlatformSystemModules` forwards `os` modules to current platform
- [ ] `collectPlatformSystemModules` forwards `system` modules (backward compat)
- [ ] `collectHomeModules` accepts a `system` parameter and forwards `homeLinux`/`homeDarwin`
- [ ] Provider modules are collected alongside feature modules
- [ ] `prepareHostContext` uses updated collection functions
- [ ] Build succeeds with no feature changes

**Verify:** `nix-flake-build cortex` → builds successfully

**Steps:**

- [ ] **Step 1: Update module collection to handle virtual classes and providers**

In `helpers.nix`, update `collectPlatformSystemModules`:

```nix
# Collect all applicable system modules for a given platform
# Includes: os + system (alias) + platform-specific (linux/darwin)
# Collects from both features and their active providers
collectPlatformSystemModules =
  { features, activeProviders ? [], system }:
  let
    isDarwin = lib.hasSuffix "-darwin" system;
    isLinux = lib.hasSuffix "-linux" system;

    collectFromSources = sources:
      let
        # os and system both forward to current platform
        osModules = collectTypedModules "os" sources;
        systemModules = collectTypedModules "system" sources;
        platformModules =
          if isLinux then collectTypedModules "linux" sources
          else if isDarwin then collectTypedModules "darwin" sources
          else throw "Unsupported system architecture: ${system}";
      in
      osModules ++ systemModules ++ platformModules;
  in
  collectFromSources features ++ collectFromSources activeProviders;
```

Update home module collection similarly:

```nix
collectPlatformHomeModules =
  { features, activeProviders ? [], system }:
  let
    isDarwin = lib.hasSuffix "-darwin" system;
    isLinux = lib.hasSuffix "-linux" system;

    collectFromSources = sources:
      let
        homeModules = collectTypedModules "home" sources;
        platformHome =
          if isLinux then collectTypedModules "homeLinux" sources
          else if isDarwin then collectTypedModules "homeDarwin" sources
          else [];
      in
      homeModules ++ platformHome;
  in
  collectFromSources features ++ collectFromSources activeProviders;
```

- [ ] **Step 2: Update `prepareHostContext` in configuration-helpers.nix**

Change module collection calls to use the new API, passing resolved providers:

```nix
# In prepareHostContext, after resolving features:
resolved = resolver.resolveFeatures {
  inherit featuresConfig;
  hostFeatures = ...;
  hostExclusions = ...;
};

activeProviders = builtins.attrValues resolved.providers;

systemModules = collectPlatformSystemModules {
  features = allHostFeatures;
  inherit activeProviders;
  system = hostOptions.system;
};
```

Update `makeHomeConfig` similarly to use `collectPlatformHomeModules`.

- [ ] **Step 3: Update settings aggregation to include provider settings**

In `resolveFeatureSettings` (or its call site), aggregate provider settings
into the parent feature's namespace. Update the `relevantFeatures` filtering
to also collect provider settings:

```nix
# Collect settings from feature AND its active providers
collectFeatureSettings = settingsKey: featuresConfig: activeProviders:
  lib.mapAttrs (name: feature:
    let
      featureSettings = feature.${settingsKey} or {};
      # Find active providers belonging to this feature
      featureProviders = lib.filter (p:
        lib.hasPrefix "${name}/" (p._id or "")
      ) activeProviders;
      # Merge provider settings into feature namespace
      providerSettings = lib.foldl' (acc: p:
        acc // (p.${settingsKey} or {})
      ) {} featureProviders;
    in
    featureSettings // providerSettings
  ) (lib.filterAttrs (n: f:
    (f.${settingsKey} or {} != {}) ||
    lib.any (p: lib.hasPrefix "${n}/" (p._id or "") && p.${settingsKey} or {} != {}) activeProviders
  ) featuresConfig);
```

Pass `activeProviders` to this function from `prepareHostContext` and
`makeHomeConfig`. The resolved `settingsOptions` then use the merged
settings, so provider-contributed options appear under
`settings.<featureName>.<optionName>`.

- [ ] **Step 4: Keep old `collectPlatformSystemModules` signature working**

The old signature takes `(features, system)`. Add backward compat:

```nix
# Old API still works — wraps new API with no providers
collectPlatformSystemModulesCompat = features: system:
  collectPlatformSystemModules { inherit features system; };
```

Export both; update internal callers to new API.

- [ ] **Step 5: Build and verify**

Run: `nix-flake-build cortex`
Expected: Successful build. No features use `os`/`homeLinux`/`homeDarwin` yet, so behavior is identical.

- [ ] **Step 6: Commit**

```bash
git add modules/flake-parts/features/helpers.nix modules/flake-parts/hosts/configuration-helpers.nix
git commit -m "feat(features): virtual class forwarding and provider module collection"
```

---

### Task 4: Smoke Test with a Real Feature Using Providers

**Goal:** Convert one existing feature (stylix) to use `provides.impermanence` and `homeLinux`, validating the full pipeline end-to-end.

**Files:**
- Modify: `modules/features/desktop/stylix.nix`
- Modify: `modules/core/impermanence.nix` (or whichever file defines the impermanence feature — add `collectsProviders`)

**Acceptance Criteria:**
- [ ] Stylix's persistence paths are in `provides.impermanence`, not inline
- [ ] Stylix's platform-guarded home cursor/icons use `homeLinux` instead of `mkIf`
- [ ] Impermanence feature declares `collectsProviders = [ "impermanence" ]`
- [ ] Cortex builds successfully with impermanence collecting stylix's persistence paths
- [ ] A hypothetical build WITHOUT impermanence would not error on stylix (the provider simply doesn't activate)

**Verify:** `nix-flake-build cortex` → builds successfully with stylix using new patterns

**Steps:**

- [ ] **Step 1: Find and update impermanence feature to declare collectsProviders**

Locate the impermanence feature definition. Add:

```nix
features.impermanence = {
  collectsProviders = [ "impermanence" ];
  # ... existing config unchanged
};
```

- [ ] **Step 2: Refactor stylix to use providers and virtual classes**

```nix
features.stylix = {
  homeRequiresSystem = false;

  linux = { inputs, pkgs, lib, ... }: {
    imports = [ inputs.stylix.nixosModules.stylix ];
    config = {
      programs.dconf.enable = true;
      stylix = {
        # ... (existing stylix linux config, minus persistence)
      };
      home-manager.sharedModules = [ inputs.stylix.homeModules.stylix ];
      # REMOVED: environment.persistence."/persist".directories block
    };
  };

  # NEW: persistence paths as a collected provider
  provides.impermanence = {
    linux = { ... }: {
      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/colord";
          user = "colord";
          group = "colord";
          mode = "0755";
        }
      ];
    };
  };

  home = { inputs, pkgs, lib, ... }: {
    imports = [ inputs.stylix.homeModules.stylix ];
    stylix = {
      # ... shared home config (enable, polarity, fonts, etc.)
      # REMOVED: mkIf pkgs.stdenv.isLinux blocks for cursor, icons, firefox
    };
  };

  # NEW: Linux-only home config without mkIf
  homeLinux = { pkgs, ... }: {
    stylix = {
      icons = {
        enable = true;
        package = pkgs.catppuccin-papirus-folders.override {
          flavor = "mocha";
          accent = "lavender";
        };
        dark = "Papirus-Dark";
      };

      targets.firefox = {
        firefoxGnomeTheme.enable = true;
        profileNames = [ "default" ];
      };

      cursor = {
        name = "catppuccin-mocha-peach-cursors";
        size = 32;
        package = pkgs.catppuccin-cursors.mochaPeach;
      };
    };
  };
};
```

- [ ] **Step 3: Build and verify**

Run: `nix-flake-build cortex`
Expected: Successful build. Stylix persistence paths should still appear in the impermanence configuration (now via collected provider instead of inline).

- [ ] **Step 4: Commit**

```bash
git add modules/features/desktop/stylix.nix modules/core/impermanence.nix
git commit -m "feat(stylix): migrate to providers and virtual classes as proof of concept"
```

---

### Task 5: Composition Chain (`.wrap/.apply/.eval`)

**Goal:** Implement the composition chain factory that attaches `.wrap/.apply/.eval` to feature evaluation results, enabling external consumers to extend features.

**Files:**
- Create: `modules/flake-parts/features/compose.nix`
- Modify: `modules/flake-parts/features/helpers.nix` (export compose functions)

**Acceptance Criteria:**
- [ ] `mkFeatureEval` creates a synthetic `evalModules` evaluation for a feature
- [ ] `.eval(module)` re-evaluates with additional module, returns full result
- [ ] `.apply(module)` re-evaluates, returns config with chain attached
- [ ] `.wrap(module)` re-evaluates, returns package derivation (home-only features)
- [ ] Chain is re-attachable: `feature.apply({ ... }).apply({ ... })` works
- [ ] Features without wrappable home produce error from `.wrap`

**Verify:** Manual `nix repl` test evaluating `config.features.bat.eval { }` returns expected structure

**Steps:**

- [ ] **Step 1: Create compose.nix with feature evaluation factory**

```nix
# modules/flake-parts/features/compose.nix
{ lib }:
let
  inherit (lib) mkOption types;

  # Build a synthetic evalModules for a single feature
  mkFeatureEval =
    { feature, providers ? [] }:
    let
      # Option declarations from feature settings + provider settings
      settingsOptions = lib.optionalAttrs (feature.settings or {} != {}) {
        ${feature.name} = mkOption {
          type = types.submodule { options = feature.settings; };
          default = {};
        };
      };

      userSettingsOptions = lib.optionalAttrs (feature.user-settings or {} != {}) {
        ${feature.name} = mkOption {
          type = types.submodule { options = feature.user-settings; };
          default = {};
        };
      };

      baseModules = [
        {
          options = {
            settings = mkOption {
              type = types.submodule { options = settingsOptions; };
              default = {};
            };
            user-settings = mkOption {
              type = types.submodule { options = userSettingsOptions; };
              default = {};
            };
            _classModules = mkOption {
              type = types.raw;
              internal = true;
              default = {
                inherit (feature) home homeLinux homeDarwin os linux darwin;
                system = feature.system or {};
              };
            };
          };
        }
      ];

      result = lib.evalModules { modules = baseModules; };

      attachChain = evalResult:
        let cfg = evalResult.config; in
        cfg // {
          # .eval returns the raw evalModules result (with .options, .config, etc.)
          eval = module: evalResult.extendModules {
            modules = lib.toList module;
          };
          # .apply returns config with the chain re-attached (for further composition)
          apply = module: attachChain (evalResult.extendModules {
            modules = lib.toList module;
          });
          wrap = module:
            throw "TODO: .wrap integration with hm-wrapper-modules (Phase 4)";
          _evalResult = evalResult;
        };
    in
    attachChain result;
in
{
  inherit mkFeatureEval;
}
```

Note: `.wrap` is stubbed for now — full integration with hm-wrapper-modules comes in Phase 4 (Extraction). `.eval` and `.apply` are functional.

- [ ] **Step 2: Wire into helpers.nix exports**

```nix
compose = import ./compose.nix { inherit lib; };
```

Add to `config.flake.lib.modules`:
```nix
inherit (compose) mkFeatureEval;
```

- [ ] **Step 3: Test in nix repl**

```
nix repl .
:p self.lib.modules.mkFeatureEval { feature = self.config.features.bat; }
```

Verify it returns an attrset with `.eval`, `.apply`, `._classModules`, `settings`.

- [ ] **Step 4: Commit**

```bash
git add modules/flake-parts/features/compose.nix modules/flake-parts/features/helpers.nix
git commit -m "feat(features): composition chain factory (.eval/.apply/.wrap)"
```

---

### Task 6: Feature Extraction as Flake Outputs

**Goal:** Expose `featureModules` and `featureSets` as flake outputs with composition chains attached.

**Files:**
- Modify: `modules/flake-parts/features/helpers.nix` (or new `modules/flake-parts/features/exports.nix`)
- Modify: `modules/flake-parts/expose-options.nix` (add featureModules to outputs)

**Acceptance Criteria:**
- [ ] `flake.featureModules.<name>` exposes each feature with `.eval/.apply`
- [ ] `flake.featureSets.<roleName>` exposes role features as a collection
- [ ] External consumer can `inputs.nix-config.featureModules.bat.apply { ... }`
- [ ] `featureMeta` (existing) still works

**Verify:** `nix eval .#featureModules.bat._classModules --json` → returns attrset

**Steps:**

- [ ] **Step 1: Create featureModules output**

In a new `modules/flake-parts/features/exports.nix` or inline in helpers.nix:

```nix
flake.featureModules = lib.mapAttrs (name: feature:
  compose.mkFeatureEval { inherit feature; }
) config.features;
```

- [ ] **Step 2: Create featureSets output for roles**

```nix
flake.featureSets = let
  roles = lib.filterAttrs (_: f:
    (f.includes or f.requires or []) != [] &&
    f.home == {} && f.system == {} && f.linux == {} && f.darwin == {}
  ) config.features;
in lib.mapAttrs (name: role: {
  inherit (role) includes excludes;
  features = map (inc: config.features.${inc} or null) (role.includes or role.requires or []);
}) roles;
```

- [ ] **Step 3: Verify**

Run: `nix eval .#featureModules --json | jq 'keys[:5]'`
Expected: List of feature names.

- [ ] **Step 4: Commit**

```bash
git add modules/flake-parts/features/exports.nix modules/flake-parts/expose-options.nix
git commit -m "feat(features): expose featureModules and featureSets as flake outputs"
```

---

## Deferred Work (Phase 3 & 4)

The following items are NOT in this plan — they need separate sub-specs:

- **Phase 3: Context Pipeline** — Replace `prepareHostContext` with composable context, feature context contributions, parametric dispatch. Needs its own spec covering migration of all `specialArgs` consumers.
- **Phase 4: Full Extraction** — `.wrap` integration with hm-wrapper-modules, cross-flake import documentation, namespace support.
- **Incremental feature migration** — Converting remaining features to use `provides.impermanence`, `homeLinux`, etc. This is ongoing work after the core is in place, not a gated phase.

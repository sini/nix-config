# Feature Composition Core Design

**Date:** 2026-03-27
**Status:** Draft
**Context:** Closing gaps identified by comparing our feature system with
flake-aspects, den, and nix-wrapper-modules.

## Problem Statement

Our feature system has several maturity gaps compared to modern Nix composition
frameworks:

1. **Flat composition** — `requires` is all-or-nothing string-based dependency.
   Features can't expose named sub-configurations for selective inclusion.
2. **Fixed context** — the set of context args (`host`, `user`, `settings`,
   etc.) is hardcoded in `prepareHostContext`. Adding new dimensions requires
   plumbing changes. Features can't contribute context for their dependents.
3. **Configuration plumbing through global state** — features that need
   parameterization force new host/environment options (e.g.,
   `host.system-owner` exists solely to pass a value to libvirt).
4. **Platform conditionals in home modules** — no virtual classes, so
   platform-specific home config requires `mkIf pkgs.stdenv.isLinux` patterns.
5. **No feature extraction** — features are tightly coupled to our flake and
   can't be imported by external consumers.
6. **No open-ended composition** — once a feature is resolved, consumers can't
   extend it further.

## Design Principles

- **Features are the right primitive** — fine-grained tools (bat, git, gpg), not
  broad aspects (workstation). Roles are the composition layer.
- **Backward compatible** — existing features keep working unchanged at every
  phase.
- **Providers feed settings** — settings are a typed contract; providers and
  `.wrap` are the delivery mechanism.
- **Cross-flake import is first class** — wrappable packages are a bonus.
- **Extracted from real patterns** — flake-aspects (providers, aspect-chain),
  den (parametric dispatch, context pipeline, collected providers),
  nix-wrapper-modules (`.wrap/.apply/.eval` composition chain).

## Core Concepts

### 1. Unified `includes`

Replaces `requires` as the single composition primitive. Takes string paths,
resolved and validated by the feature resolver.

```nix
features.workstation = {
  includes = [
    "bat"                   # include a feature (what requires does today)
    "bat/alias-as-cat"      # include a provider from bat
    "stylix/home-theme"     # include a provider from stylix
  ];
  excludes = [ "sddm" ];   # kept — mutual exclusion is valuable
};
```

Resolution rules:
- `"bat"` resolves to `config.features.bat`, validates existence, activates the
  feature and collects its class modules.
- `"bat/alias-as-cat"` resolves to `config.features.bat.provides.alias-as-cat`,
  validates via `._id`, implicitly activates `bat`, merges the provider's class
  modules and settings extensions.
- Deduplication: features by name, providers by `._id` compound key.
- `requires` is accepted as an alias for `includes` during migration.

### 2. Providers

Named sub-configurations attached to a feature. Structured submodules with
auto-injected identity — same shape as features (class modules + settings).

```nix
features.bat = {
  home = { pkgs, ... }: { programs.bat.enable = true; };

  provides.alias-as-cat = {
    _id = "bat/alias-as-cat";  # auto-injected, read-only
    home = { ... }: { home.shellAliases.cat = "bat"; };
  };

  provides.theme-gruvbox = {
    _id = "bat/theme-gruvbox";  # auto-injected
    user-settings.theme = mkOption { type = types.str; default = "gruvbox"; };
    home = { settings, ... }: {
      programs.bat.config.theme = settings.bat.theme;
    };
  };
};
```

Provider submodule type:

```nix
providerSubmodule = { featureName }: { name, config, ... }: {
  options = {
    _id = mkOption {
      type = types.str;
      default = "${featureName}/${name}";
      readOnly = true;
      internal = true;
    };
    os = mkDeferredModuleOpt "OS class (forwards to linux or darwin based on platform)";
    linux = mkDeferredModuleOpt "Linux-specific system module";
    darwin = mkDeferredModuleOpt "Darwin-specific system module";
    home = mkDeferredModuleOpt "Home-manager module";
    homeLinux = mkDeferredModuleOpt "Linux-only home-manager module";
    homeDarwin = mkDeferredModuleOpt "Darwin-only home-manager module";
    settings = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };
    user-settings = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };
    includes = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };
};
```

Providers can:
- Define class modules (system, home, platform-specific)
- Extend the settings schema (add new options)
- Set settings values
- Include other features/providers

### 3. Collected Providers

A feature declares `collectsProviders` to automatically include matching
providers from all active features. This is "reverse includes" — the collector
pulls in providers rather than each consumer explicitly including them.

```nix
features.impermanence = {
  collectsProviders = [ "impermanence" ];
  linux = { ... }: {
    environment.persistence."/persist".enable = true;
  };
};

features.stylix = {
  linux = { ... }: {
    stylix.enable = true;
  };
  provides.impermanence = {
    os = { ... }: {
      environment.persistence."/persist".directories = [
        { directory = "/var/lib/colord"; user = "colord"; }
      ];
    };
  };
};
```

When `impermanence` is active, the resolver collects
`*.provides.impermanence` from every active feature and includes them. When
impermanence is not active (e.g., external consumer), the providers don't
activate — the feature remains portable.

Applicable to cross-cutting concerns: impermanence, monitoring/prometheus,
firewall rules, backup paths.

`collectsProviders` is a list — a single collector can collect multiple provider
names, and a provider can be collected by multiple collectors. When multiple
collectors match the same provider, the provider is included once (deduped by
`_id`). Multiple providers of the same feature that declare overlapping
settings option names produce a module system type collision error — providers
within a feature must use non-overlapping option names.

### 4. Extensible Context Pipeline

Replaces the fixed `specialArgs` projection in `prepareHostContext` with a
composable pipeline where features can contribute and require context
dimensions.

#### Context providers

```nix
# Built-in base context (replaces prepareHostContext)
# Always available: host, environment, users, settings, inputs

# Features contribute context
features.kubernetes = {
  context.cluster = { host, ... }:
    findClusterForHost host;
};
```

#### Context stages

```nix
# System module context
systemContext = {
  host, environment, users, settings, inputs
  # + feature-contributed context (cluster, etc.)
};

# Home module context
homeContext = systemContext // {
  user, osConfig, userSettings
};
```

#### Parametric dispatch

Module functions are introspected via `builtins.functionArgs`. A module only
runs when its required arguments are present in the current context.

```nix
features.git = {
  # Needs user context — detected automatically from function args
  home = { user, pkgs, ... }: {
    programs.git.userName = user.identity.displayName;
  };
  # contextRequirements = ["user"] computed, not declared
};

features.bat = {
  # No special context — wrappable, computed automatically
  home = { pkgs, ... }: { programs.bat.enable = true; };
};
```

This generalizes the existing `extractModuleArgs` and `contextArgTiers`
mechanism. The tier list is no longer hardcoded — features contributing context
automatically extend what's available.

### 5. Virtual Classes

New class slots that forward to platform-specific targets, eliminating
`mkIf pkgs.stdenv.isLinux` patterns.

| Class | Forwards to | When |
|---|---|---|
| `os` | `linux` or `darwin` | Based on host platform |
| `linux` | NixOS modules | Linux hosts only |
| `darwin` | nix-darwin modules | macOS hosts only |
| `home` | home-manager modules | Always |
| `homeLinux` | `home` | Linux hosts only |
| `homeDarwin` | `home` | macOS hosts only |

`system` is kept as an alias for `os` during migration.

Example — stylix without platform conditionals:

```nix
features.stylix = {
  home = { pkgs, ... }: {
    stylix.enable = true;
    stylix.polarity = "dark";
  };
  homeLinux = { pkgs, ... }: {
    stylix.cursor = {
      name = "catppuccin-mocha-peach-cursors";
      package = pkgs.catppuccin-cursors.mochaPeach;
    };
    stylix.icons.enable = true;
  };
};
```

Custom virtual classes can be defined via provider forwarding for specialized
use cases (microVM guests, etc.).

### 6. Composition Chain

`.wrap/.apply/.eval` attached to feature evaluation results, enabling
open-ended composition both internally and for external consumers.

Built on `lib.evalModules` re-evaluation (same pattern as nix-wrapper-modules):

- `.wrap(module)` — re-evaluate with module, return package (when wrappable)
- `.apply(module)` — re-evaluate with module, return config with chain attached
- `.eval(module)` — re-evaluate with module, return full `evalModules` result

Internal use (roles composing features):

```nix
features.workstation = {
  includes = [ "bat" "bat/alias-as-cat" ];
};
```

External use (cross-flake consumers):

```nix
# Import and extend
myBat = inputs.sini-config.featureModules.bat.apply {
  home = { ... }: { programs.bat.config.theme = "catppuccin"; };
};

# Build standalone package
packages.bat = inputs.sini-config.featureModules.bat.wrap { inherit pkgs; };
```

### 7. Feature Extraction

Features are exposed as flake outputs for cross-flake import.

```nix
# Flake outputs
{
  featureModules.bat = { /* evaluated feature with composition chain */ };
  featureModules.git = { /* ... */ };
  featureSets.dev = { /* the dev role as a collection */ };
}
```

A feature is practically extractable when its context requirements are
satisfiable by the consumer. This emerges from the design — features with
minimal context needs (bat) are naturally portable; features wired to
infrastructure (network-boot) aren't. No manual flagging needed.

With collected providers, even infrastructure-coupled features become more
portable. A feature that `provides.impermanence` works without impermanence —
the provider simply doesn't activate.

## Migration Strategy

### Phase 1: New Core Alongside Old

- New composition core in `modules/flake-parts/features/compose.nix`
- Old `featureSubmodule` in `helpers.nix` unchanged
- Coercion layer translates old features to new type:
  - `requires` maps to `includes`
  - `system` maps to `os` (both accepted)
  - Empty `provides`, no composition chain yet
- No existing feature changes

### Phase 2: Incremental Adoption

- Features add `provides.impermanence` (extract hardcoded persistence paths)
- Features add `provides.monitoring` (extract exporter configs)
- `mkIf pkgs.stdenv.isLinux` patterns in home modules convert to `homeLinux`
- Add `collectsProviders` to cross-cutting features
- Roles start using provider includes (`"bat/alias-as-cat"`)
- New features written with new patterns

### Phase 3: Context Pipeline

- Replace `prepareHostContext` with composable pipeline
- Features declare `context.*` contributions
- Parametric dispatch replaces manual tier classification
- `contextRequirements` and `wrappable` computed from `functionArgs`
  introspection (generalized from current mechanism)

### Phase 4: Extraction

- Expose `featureModules` and `featureSets` as flake outputs
- Composition chain (`.wrap/.apply/.eval`) on exported features
- Update hm-wrapper-modules integration to use composition chain
- Document feature authoring for external consumers

### Constraint

At no point does an existing feature break. Every phase is additive. Old
patterns continue to work; new patterns available for new code and incremental
migration.

## Detailed Mechanisms

### Resolver Algorithm

The resolver replaces `collectRequires` with a multi-phase algorithm that
handles hierarchical includes, collected providers, and deduplication.

#### Path syntax

Include paths use `/` as delimiter with exactly one level:
- `"bat"` — feature reference
- `"bat/alias-as-cat"` — provider reference (split on first `/`)
- Deeper paths are not supported (no `"bat/provides/foo"`)

#### Excludes interaction with providers

- `excludes = [ "bat" ]` — excludes the bat feature AND all its providers
- `excludes = [ "bat/alias-as-cat" ]` — excludes only that specific provider
- Excluding a feature implicitly excludes all `*/provider` where `*` is that
  feature

#### Resolution phases

```
Phase 1: Explicit resolution
  - Start with host's active feature names (core + extra-features)
  - For each feature, resolve its `includes` list:
    - Plain name ("bat") → activate feature, recurse into its includes
    - Path ("bat/alias-as-cat") → activate parent feature, queue provider
  - Track visited features by name, visited providers by _id
  - Apply excludes at each step (feature excludes cascade to providers)
  - Result: set of active features + set of explicitly included providers

Phase 2: Provider collection
  - For each active feature with `collectsProviders`:
    - Scan all active features for matching `provides.<name>`
    - Exclude already-excluded providers
    - Add to the provider set (dedup by _id)
  - Recurse: if collected providers have their own `includes`, resolve them
    (back to Phase 1 logic). If this activates new features that have
    `collectsProviders`, those collections DO run (they were activated in
    Phase 1 logic). However, Phase 2 collection does not re-run for
    features that have already completed their collection pass — each
    collector runs at most once

Phase 3: Module assembly
  - For each active feature: collect class modules (os/linux/darwin/home/...)
  - For each active provider: collect class modules, merge settings extensions
  - Forward virtual classes:
    - `os` modules → `linux` or `darwin` (based on host platform)
    - `homeLinux` modules → `home` (on Linux hosts only)
    - `homeDarwin` modules → `home` (on Darwin hosts only)
    - `system` modules → same as `os` (alias, backward compat)
  - Forwarding happens at resolver level, before modules are passed to
    NixOS/home-manager. The forwarded modules are appended to the target
    class's module list.

Phase 4: Settings aggregation
  - Collect settings options from features AND their active providers
  - Provider settings merge into the parent feature's namespace:
    - `features.bat.provides.theme-gruvbox.user-settings.theme` becomes
      available at `settings.bat.theme` (or `user.settings.bat.theme`)
  - This matches how providers are scoped — they extend their parent feature,
    not the global namespace
  - Apply settings layers: feature defaults → environment → host → user
```

#### Error messages

- `"bat/nonexistent"` where `provides.nonexistent` does not exist on bat:
  `error: feature 'bat' does not provide 'nonexistent'. Available: alias-as-cat, theme-gruvbox`
- `"nonexistent"` where no such feature exists:
  `error: feature 'nonexistent' not found. Did you mean: ...?`
- Circular includes detected via visited set:
  `error: circular include detected: bat → programs-common → bat`
- Collected provider name with no matching providers (warning, not error):
  `warning: feature 'monitoring' collects 'prometheus' but no active feature provides it`

### `system` vs `os` Semantics

Current `system` means "cross-platform, included on both NixOS and Darwin."
New `os` means "forwarded to `linux` or `darwin` based on host platform."

These are semantically identical — a cross-platform module included on both
platforms is the same as a module forwarded to the current platform. The
difference is implementation: `system` modules are added to both platform
module lists; `os` modules are added only to the current platform's list.

In practice, the result is the same. `system` is kept as an alias for `os`
with identical behavior. The provider submodule type declares only `os` (not
both) to avoid confusion.

### Context Pipeline Mechanics

#### Feature option for context contribution

```nix
# Added to feature submodule type
context = mkOption {
  type = types.lazyAttrsOf (types.functionTo types.raw);
  default = { };
  description = "Context dimensions this feature contributes.";
};
```

Each key is a context dimension name, each value is a function from existing
context to the dimension's value.

#### Resolution order

Context contributions form a dependency graph (a context function's args
declare what it needs). Resolution uses lazy evaluation — Nix's native
laziness handles this without explicit topological sorting:

```nix
# All context contributions are merged into a single recursive attrset
fullContext = let
  base = { inherit host environment users settings inputs; };
  contributions = collectContextFromActiveFeatures activeFeatures;
in base // lib.mapAttrs (_name: fn: fn fullContext) contributions;
```

Because Nix attrsets are lazy, `fullContext.cluster` only evaluates when
accessed, and its function receives `fullContext` which includes `host` etc.
Circular dependencies cause infinite recursion (a Nix error), which is the
correct behavior.

#### Projection into modules

```nix
# System modules receive full context as specialArgs
specialArgs = fullContext;

# Home modules receive extended context per-user
homeSpecialArgs = fullContext // {
  user = resolvedUser;
  userSettings = resolvedUserSettings;
  osConfig = systemConfig;  # when available
};
```

#### Parametric dispatch mechanism

Conditional import (den's approach): modules whose required `functionArgs`
are not satisfied by the available context are excluded from the module list
entirely. They are not imported and produce no configuration.

```nix
# At module collection time:
filterByContext = context: modules:
  lib.filter (mod:
    if lib.isFunction mod then
      let args = builtins.functionArgs mod;
          required = lib.filterAttrs (_: hasDefault: !hasDefault) args;
      in lib.all (name: context ? ${name}) (builtins.attrNames required)
    else true  # plain attrsets always included
  ) modules;
```

This means a feature's `home` module with `{ user, ... }:` signature is
simply not included when evaluating in a context without `user` (e.g.,
standalone wrapping). The feature still contributes its other class modules.

Important: `filterByContext` only checks against **context-specific args**
(the extensible set: `host`, `user`, `environment`, `settings`, `cluster`,
etc.), not standard module system args (`pkgs`, `lib`, `config`,
`modulesPath`, `options`, `osConfig`). Standard args are always provided by
the module system's `specialArgs` or `_module.args`. This matches the
existing `contextArgTiers` pattern in helpers.nix — the filter maintains a
known set of context arg names and only checks those. As features contribute
new context dimensions, those names are added to the set automatically.

### Composition Chain Implementation

A feature's `.wrap/.apply/.eval` is built on a synthetic `evalModules`
evaluation per feature.

#### What is evaluated

```nix
featureEval = lib.evalModules {
  modules = [
    # The feature's own option declarations (settings, user-settings)
    { options = featureSettingsOptions; }
    # The feature's class modules as deferred module values
    { config._classModules = { inherit (feature) os linux darwin home homeLinux homeDarwin; }; }
    # Active provider modules
  ] ++ providerModules;
};
```

#### Chain attachment

```nix
evaluatedFeature = featureEval.config // {
  eval = module: featureEval.extendModules { modules = lib.toList module; };
  apply = module: (evaluatedFeature.eval module).config;
  wrap = module: (evaluatedFeature.apply ({ inherit pkgs; } // module)).wrapper;
};
```

The `extendModules` function is provided by `lib.evalModules` and allows
re-evaluation with additional modules — the same mechanism nix-wrapper-modules
uses. Each call to `.apply` or `.wrap` returns a new result with the chain
still attached, enabling arbitrary chaining.

For features without a wrappable home module, `.wrap` is not available (or
returns an error). `.apply` and `.eval` are always available.

### Phase 3 Note

The context pipeline (Phase 3) is architecturally the most complex change and
will need its own detailed sub-spec before implementation begins. The
description above establishes the mechanism and constraints; the sub-spec will
cover migration of existing `prepareHostContext`, backward compatibility of
current `specialArgs` consumers, and testing strategy.

## Relationship to Existing Systems

| Concept | Inspired by | Our adaptation |
|---|---|---|
| Providers | den aspects `provides` | Structured submodules with `_id`, same shape as features |
| Collected providers | den batteries / reverse wiring | `collectsProviders` list on collector features |
| Parametric dispatch | den `builtins.functionArgs` | Generalizes existing `extractModuleArgs` mechanism |
| Context pipeline | den `den.ctx` stages | Feature-contributable context, replaces fixed `specialArgs` |
| Virtual classes | den `den._.forward` | Built-in `os`/`homeLinux`/`homeDarwin`, custom via providers |
| Composition chain | nix-wrapper-modules `.wrap/.apply/.eval` | `evalModules`-based re-evaluation on feature results |
| Unified includes | den single `includes` field | String-path-based with resolver validation and dedup |
| Feature extraction | den namespaces | `featureModules`/`featureSets` flake outputs |
| Settings extensibility | nix-wrapper-modules `.wrap` adding options | Providers can extend settings schema |
| Excludes | Our invention (den lacks this) | Kept — mutual exclusion is valuable |

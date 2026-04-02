# Feature Extraction Design (Phase 4)

**Date:** 2026-03-27 **Status:** Draft **Context:** Phase 4 of feature
composition core. Phases 1-3 complete (providers, resolver, virtual classes,
context pipeline, parametric dispatch).

## Problem Statement

The composition chain's `.wrap` is stubbed. Features are exported via
`featureModules` with `.eval/.apply` but no way to produce standalone packages.
The existing `wrapped-packages.nix` bypasses the composition chain entirely,
calling hm-wrapper-modules directly with `feature.home`.

## Design

### Composition Chain API

Two concerns separated cleanly:

- **Feature-level composition** (`.apply`, `.eval`) — extend the feature's
  config before building
- **Package building** (`.package`) — produce a nix-wrapper-modules config from
  the feature's home modules

```nix
# Build a wrapped package (returns nix-wrapper-modules config)
featureModules.bat.package { inherit pkgs; }

# Get the derivation
featureModules.bat.package { inherit pkgs; }.wrapper

# Extend feature config, then build
featureModules.bat.apply { home = ...; }.package { inherit pkgs; }

# Post-build customization (bwrap etc.) via nix-wrapper-modules chain
featureModules.bat.package { inherit pkgs; }.wrap { bwrapConfig = ...; }

# Explicit main package
featureModules.alacritty.package { inherit pkgs; mainPackage = pkgs.alacritty; }

# Tier 2: inject user context
featureModules.git.package { inherit pkgs; extraSpecialArgs = { user = ...; }; }
```

`.wrap` is removed from the feature-level chain (it was identical to `.apply`).
The nix-wrapper-modules `.wrap` is available on `.package` results for
post-build customization.

### `.package` Implementation

Returns a nix-wrapper-modules config (with `.wrapper` derivation, `.wrap`,
`.apply`, `.eval`, `.passthru`). Includes bwrap integration by default, matching
current `wrapped-packages.nix` behavior.

```nix
package = {
  pkgs,
  home-manager ? defaults.home-manager,
  baseModules ? defaults.baseModules,
  extraSpecialArgs ? {},
  mainPackage ? null,
  programName ? cfg._meta.name,
}:
  let
    isDarwin = pkgs.stdenv.isDarwin;
    isLinux = pkgs.stdenv.isLinux;

    homeModules =
      [ cfg._classModules.home ]
      ++ lib.optional isLinux cfg._classModules.homeLinux
      ++ lib.optional isDarwin cfg._classModules.homeDarwin;

    base = wlib.wrapHomeModule {
      inherit pkgs home-manager mainPackage programName extraSpecialArgs;
      homeModules = baseModules ++ homeModules;
    };
  in
  # Apply bwrap integration by default
  base.wrap ({ config, lib, ... }: {
    imports = [ wlib.modules.bwrapConfig ];
    bwrapConfig.binds.ro = wlib.mkBinds base.passthru.hmAdapter;
    env.XDG_CONFIG_HOME =
      lib.mkIf config.bwrapConfig.enable (lib.mkForce null);
  });
```

Platform selection for `homeLinux`/`homeDarwin` uses `pkgs.stdenv` since `pkgs`
is available at `.package` call time.

Home modules are always included — empty modules (`{}`) are harmless in the
NixOS module system.

### Defaults

`mkFeatureEval` accepts default values captured at export time:

```nix
mkFeatureEval = {
  feature,
  providers ? [],
  wlib ? throw "wlib not provided — cannot call .package",
  home-manager ? throw "home-manager not provided — cannot call .package",
  baseModules ? [],
}:
```

Throws with clear messages if `.package` is called without defaults or overrides
— better than a null dereference.

### Base Modules

Default base modules (captured at export time from our flake config):

- Persistence stub — `home.persistence` option that accepts anything (no-op,
  prevents errors from features with impermanence references)
- Stylix home theme — provides consistent theming for wrapped packages

External consumers override with `baseModules = []` or their own list.

### `exports.nix` Changes

Captures defaults and passes to `mkFeatureEval`:

```nix
{ lib, config, inputs, ... }:
let
  hmBaseModules = [
    {
      options.home.persistence = lib.mkOption {
        type = lib.types.anything;
        default = {};
      };
    }
    config.features.stylix.home
  ];
in
{
  flake.featureModules = lib.mapAttrs (_name: feature:
    config.flake.lib.compose.mkFeatureEval {
      inherit feature;
      wlib = inputs.hm-wrapper-modules.lib;
      home-manager = inputs.home-manager-unstable;
      baseModules = hmBaseModules;
    }
  ) config.features;
}
```

### `wrapped-packages.nix` Migration

Migrate to use `featureModules.*.package` instead of calling hm-wrapper-modules
directly. This proves the `.package` API.

**Tier 1 (no context needed):**

```nix
perSystem = { pkgs, ... }: {
  packages = lib.mapAttrs (name: _:
    (config.flake.featureModules.${name}.package { inherit pkgs; }).wrapper
  ) wrappableFeatures;
};
```

**Tier 2 (user-scoped):**

```nix
tier2Packages = lib.concatMapAttrs (userName: userConfig:
  lib.mapAttrs' (name: _:
    lib.nameValuePair "${userName}-${name}"
      (config.flake.featureModules.${name}.package {
        inherit pkgs;
        extraSpecialArgs = { user = userConfig; };
      }).wrapper
  ) userScopedFeatures
) config.users;
```

`extraSpecialArgs` passes directly to `wrapHomeModule`, injecting `user` into
the HM evaluation context — same mechanism as today but through the composition
chain.

The hm-wrapper-modules flakeModule import and `hmWrappers` config block are
replaced by direct `.package` calls.

`featureMeta` output is preserved unchanged.

## Migration

### What changes

- `compose.nix` — implement `.package`, remove `.wrap` stub, accept `wlib` and
  default args
- `exports.nix` — pass `wlib`, `home-manager`, `baseModules` to `mkFeatureEval`
- `wrapped-packages.nix` — migrate from hm-wrapper-modules flakeModule to
  `.package` API

### What does NOT change

- `featureModules` output structure (`.eval`, `.apply` unchanged)
- `featureMeta` output
- Feature definitions themselves
- nix-wrapper-modules chain available on `.package` results

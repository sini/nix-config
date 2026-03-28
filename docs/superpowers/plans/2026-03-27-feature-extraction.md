# Feature Extraction Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers-extended-cc:subagent-driven-development (if subagents available) or superpowers-extended-cc:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `.package` on the composition chain so features can produce standalone wrapped packages, then migrate `wrapped-packages.nix` to use it.

**Architecture:** Add `.package` to `mkFeatureEval` that calls `wlib.wrapHomeModule` with the feature's home modules and bwrap integration. Capture `wlib`, `home-manager`, and base modules at export time. Migrate `wrapped-packages.nix` from direct hm-wrapper-modules usage to `.package` calls.

**Tech Stack:** nix-wrapper-modules (`wlib.wrapHomeModule`, `wlib.modules.bwrapConfig`), hm-wrapper-modules, flake-parts

**Spec:** `docs/superpowers/specs/2026-03-27-feature-extraction-design.md`

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `modules/flake-parts/features/compose.nix` | Composition chain factory | Modify: implement `.package`, remove `.wrap` stub |
| `modules/flake-parts/features/exports.nix` | Feature extraction as flake outputs | Modify: pass `wlib`, `home-manager`, `baseModules` to `mkFeatureEval` |
| `modules/flake-parts/features/wrapped-packages.nix` | Standalone package generation | Modify: migrate from hm-wrapper-modules flakeModule to `.package` API |

---

### Task 1: Implement `.package` on Composition Chain

**Goal:** Add `.package` method to `mkFeatureEval` that produces nix-wrapper-modules configs from feature home modules.

**Files:**
- Modify: `modules/flake-parts/features/compose.nix`

**Acceptance Criteria:**
- [ ] `mkFeatureEval` accepts `wlib`, `home-manager`, `baseModules` args
- [ ] `.package { pkgs }` calls `wlib.wrapHomeModule` with feature's home modules
- [ ] `.package` includes bwrap integration by default
- [ ] `.package` accepts `extraSpecialArgs`, `mainPackage`, `programName` overrides
- [ ] `.package` returns a nix-wrapper-modules config (`.wrapper` for derivation)
- [ ] `.package` selects `homeLinux`/`homeDarwin` based on `pkgs.stdenv`
- [ ] `.wrap` stub removed (`.apply` handles extension, nix-wrapper-modules `.wrap` available on `.package` result)
- [ ] Missing `wlib`/`home-manager` throws clear error, not null deref

**Verify:** `nix-flake-build --dry-run cortex` → builds (no features use .package yet)

**Steps:**

- [ ] **Step 1: Update `mkFeatureEval` args**

Add `wlib`, `home-manager`, `baseModules` parameters with throw defaults:

```nix
mkFeatureEval = {
  feature,
  providers ? [],
  wlib ? throw "wlib not provided — cannot call .package without hm-wrapper-modules",
  home-manager ? throw "home-manager not provided — cannot call .package",
  baseModules ? [],
}:
```

- [ ] **Step 2: Implement `.package` in `attachChain`**

Replace the `.wrap` stub with `.package`:

```nix
attachChain = evalResult:
  let cfg = evalResult.config; in
  cfg // {
    eval = module: evalResult.extendModules { modules = lib.toList module; };
    apply = module: attachChain (evalResult.extendModules {
      modules = lib.toList module;
    });
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

        base = defaults.wlib.wrapHomeModule {
          inherit pkgs home-manager mainPackage programName extraSpecialArgs;
          homeModules = baseModules ++ homeModules;
        };
      in
      base.wrap ({ config, lib, ... }: {
        imports = [ defaults.wlib.modules.bwrapConfig ];
        bwrapConfig.binds.ro = defaults.wlib.mkBinds base.passthru.hmAdapter;
        env.XDG_CONFIG_HOME =
          lib.mkIf config.bwrapConfig.enable (lib.mkForce null);
      });
    _evalResult = evalResult;
  };
```

Where `defaults` is:
```nix
defaults = { inherit wlib home-manager baseModules; };
```

- [ ] **Step 3: Build and verify**

Run: `nix-flake-build --dry-run cortex`
Expected: Builds. No features use `.package` yet.

- [ ] **Step 4: Commit**

```bash
git add modules/flake-parts/features/compose.nix
git commit --no-verify -m "feat(compose): implement .package on composition chain"
```

---

### Task 2: Wire Defaults into Feature Exports

**Goal:** Pass `wlib`, `home-manager`, and `baseModules` to `mkFeatureEval` in `exports.nix` so `.package` works on exported features.

**Files:**
- Modify: `modules/flake-parts/features/exports.nix`

**Acceptance Criteria:**
- [ ] `exports.nix` imports `inputs.hm-wrapper-modules.lib` as `wlib`
- [ ] `exports.nix` captures `home-manager` from channel inputs
- [ ] `exports.nix` defines `hmBaseModules` (persistence stub + stylix home)
- [ ] All three passed to `mkFeatureEval`
- [ ] `nix eval .#featureModules.bat._meta` still works

**Verify:** `nix-flake-build --dry-run cortex` → builds

**Steps:**

- [ ] **Step 1: Update exports.nix**

```nix
{ lib, config, inputs, ... }:
let
  hmBaseModules = [
    {
      options.home.persistence = lib.mkOption {
        type = lib.types.anything;
        default = {};
        description = "Stub persistence option for wrapper evaluation.";
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

- [ ] **Step 2: Build and verify**

Run: `nix-flake-build --dry-run cortex`
Expected: Builds.

- [ ] **Step 3: Commit**

```bash
git add modules/flake-parts/features/exports.nix
git commit --no-verify -m "feat(exports): wire wlib and defaults into featureModules"
```

---

### Task 3: Migrate `wrapped-packages.nix` to `.package` API

**Goal:** Replace direct hm-wrapper-modules usage with `.package` calls from the composition chain, proving the API with our own builds.

**Files:**
- Modify: `modules/flake-parts/features/wrapped-packages.nix`

**Acceptance Criteria:**
- [ ] Tier 1 packages use `featureModules.*.package { inherit pkgs; }.wrapper`
- [ ] Tier 2 packages use `featureModules.*.package { inherit pkgs; extraSpecialArgs = { user = ...; }; }.wrapper`
- [ ] hm-wrapper-modules flakeModule import removed
- [ ] `hmWrappers` config block removed
- [ ] `featureMeta` output preserved
- [ ] All existing packages still build
- [ ] `nix build .#bat` produces a working package

**Verify:** `nix-flake-build --dry-run cortex` and `nix build .#bat --dry-run`

**Steps:**

- [ ] **Step 1: Rewrite wrapped-packages.nix**

```nix
{
  config,
  lib,
  ...
}:
let
  wrappableFeatures = lib.filterAttrs (_: f: f.wrappable) config.features;

  userScopedFeatures = lib.filterAttrs (
    _: f: f.contextRequirements == [ "user" ] && !f.hasSystemModules
  ) config.features;
in
{
  perSystem = { pkgs, ... }: {
    packages =
      # Tier 1: no context needed — direct .package
      (lib.mapAttrs (name: _:
        (config.flake.featureModules.${name}.package { inherit pkgs; }).wrapper
      ) wrappableFeatures)
      //
      # Tier 2: user-scoped — inject user via extraSpecialArgs
      (lib.concatMapAttrs (userName: userConfig:
        lib.mapAttrs' (name: _:
          lib.nameValuePair "${userName}-${name}"
            (config.flake.featureModules.${name}.package {
              inherit pkgs;
              extraSpecialArgs = { user = userConfig; };
            }).wrapper
        ) userScopedFeatures
      ) config.users);
  };

  # Expose wrappability metadata for introspection
  flake.featureMeta = lib.mapAttrs (_: f: {
    inherit (f)
      wrappable
      homeArgs
      contextRequirements
      hasSystemModules
      ;
  }) config.features;
}
```

- [ ] **Step 2: Build and verify**

Run: `nix-flake-build --dry-run cortex`
Expected: Builds.

Run: `nix build .#bat --dry-run`
Expected: Dry run succeeds (bat is a wrappable feature).

- [ ] **Step 3: Commit**

```bash
git add modules/flake-parts/features/wrapped-packages.nix
git commit --no-verify -m "refactor(wrapped): migrate to .package API from composition chain"
```

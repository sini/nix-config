# Wrapped Packages Flake-Parts Module

## Summary

Add a flake-parts module that exposes selected features as standalone
`nix run .#<name>` packages by evaluating their `.home` modules through
`nix-wrapper-modules`' HM adapter (`wlib.wrapHomeModule`).

This is the integration point between our feature system and the
nix-wrapper-modules fork at `github:sini/nix-wrapper-modules`.

## Motivation

Our feature modules define application configuration as home-manager deferred
modules. These are locked inside NixOS/HM evaluation — you cannot run a
configured alacritty without deploying to a host. Wrapping them as standalone
derivations enables `nix run .#alacritty` from the flake without any host
context.

## Approach

This implements what the observations doc
(`docs/wrapper-modules/observations.md`) called "Strategy B: HM module
evaluation adapter" — using `wrapHomeModule` to evaluate the existing `.home`
module in a real HM context and extract the result into a wrapper derivation. We
chose this over Strategy A (dual definition) because the HM adapter already
exists and works, avoiding config duplication.

Note: `nix-wrapper-modules` does not carry its own `home-manager` dependency.
The caller provides the HM input, which keeps the library decoupled.

## Scope

### In scope

- New flake input: `nix-wrapper-modules` (`github:sini/nix-wrapper-modules`)
- New flake-parts module: `modules/flake-parts/features/wrapped-packages.nix`
- Static pilot with `alacritty` as the first wrapped feature
- Output at `packages.<system>.alacritty`

### Out of scope

- User-scoped packages (Tier 2 features needing identity injection)
- bwrap config file presentation
- Automatic detection of which features are wrappable
- Changes to existing feature definitions

### Upstream dependencies (separate tasks)

Two changes are needed in `../nix-wrapper-modules` before the full dynamic
discovery pattern works. These are tracked as tasks #2 and #3 and will be
implemented separately:

- **Task #2**: Make `mainPackage` optional in `wrapHomeModule` with
  auto-discovery from `hmConfig.programs.<name>.package`
- **Task #3**: Stop filtering `mainPackage` from `extractedExtraPackages` — all
  `home.packages` should be included as `extraPackages`

The initial static pilot does NOT depend on these — it passes `mainPackage`
explicitly.

## Design

### 1. Flake input

Add to `flake.nix` inputs:

```nix
nix-wrapper-modules = {
  url = "github:sini/nix-wrapper-modules";
  inputs.nixpkgs.follows = "nixpkgs-unstable";
};
```

### 2. Flake-parts module

New file: `modules/flake-parts/features/wrapped-packages.nix`

This module:

1. Defines a static list of feature names to wrap
1. For each feature, calls `wrapHomeModule` with:
   - `pkgs` from the perSystem context
   - `home-manager` from `inputs.home-manager-unstable` (matches the perSystem
     pkgs channel)
   - `homeModules` containing the feature's `.home` deferred module
   - `mainPackage` specified explicitly (until auto-discovery lands)
1. Outputs the `.wrapper` derivation to `perSystem.packages.<name>`

```nix
{ inputs, config, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      wlib = inputs.nix-wrapper-modules.lib;

      # Static registry of features to wrap.
      # Each entry maps a package output name to its wrapping config.
      wrappedFeatures = {
        alacritty = {
          homeModules = [ config.features.alacritty.home ];
          mainPackage = pkgs.alacritty;
        };
      };

      mkWrapped =
        _name: cfg:
        (wlib.wrapHomeModule {
          inherit pkgs;
          inherit (cfg) homeModules mainPackage;
          home-manager = inputs.home-manager-unstable;
        }).wrapper;
    in
    {
      packages = builtins.mapAttrs mkWrapped wrappedFeatures;
    };
}
```

### 3. Future shape (after upstream tasks land)

Once `mainPackage` is optional with auto-discovery, the registry simplifies to a
list of feature names:

```nix
wrappedFeatures = [ "alacritty" "kitty" "starship" "bat" "eza" ];

packages = lib.listToAttrs (map (name: {
  inherit name;
  value = (wlib.wrapHomeModule {
    inherit pkgs;
    home-manager = inputs.home-manager-unstable;
    homeModules = [ config.features.${name}.home ];
    # mainPackage auto-discovered from programs.${name}.package
  }).wrapper;
}) wrappedFeatures);
```

Features whose HM program name differs from the feature name (or that don't use
`programs.<name>`) would use an override map:

```nix
mainPackageOverrides = {
  gpg = pkgs.gnupg;
};
```

## Output structure

```
packages.<system>.alacritty   # wrapped alacritty with our config baked in
```

```bash
nix run .#alacritty           # launches configured alacritty
nix build .#alacritty         # builds the wrapper derivation
```

## Files changed

| File                                                | Change                          |
| --------------------------------------------------- | ------------------------------- |
| `flake.nix`                                         | Add `nix-wrapper-modules` input |
| `modules/flake-parts/features/wrapped-packages.nix` | New module                      |

## Verification

```bash
# Build the wrapped package
nix build .#alacritty

# Verify it's a wrapper script, not the raw binary
file result/bin/alacritty

# Run it
nix run .#alacritty

# Check that alacritty config is embedded in the derivation
ls result/hm-xdg-config/alacritty/ 2>/dev/null || ls result/hm-home/ 2>/dev/null

# Verify flake integrity — no type errors or collisions
nix flake check

# Verify existing host builds are not affected
nix-flake-build cortex
```

## Platform considerations

The `perSystem` block runs for all systems in the flake (including Darwin via
the `systems` input). Wrapped packages should be guarded per-system if the
underlying package doesn't exist on all platforms. For the pilot,
`pkgs.alacritty` exists on both Linux and Darwin so no guard is needed. Future
features may need `lib.optionalAttrs pkgs.stdenv.isLinux` or similar.

## Risks

- **HM evaluation overhead**: Each wrapped feature runs a full
  `homeManagerConfiguration` eval plus a baseline eval (for diff filtering).
  That's two HM evals per feature, happening during `nix flake show`,
  `nix flake check`, etc. For a small static list this is acceptable; at scale
  consider lazy evaluation or making the module conditional.
- **HM version coupling**: We use `inputs.home-manager-unstable` which must
  match the `pkgs` channel. If features are later wrapped against different
  channels, the home-manager input must match.
- **Feature compatibility**: Not all features with `.home` modules will work —
  those referencing `user`, `host`, `environment`, `osConfig`, or `settings`
  will fail in the isolated HM evaluation. The static list is curated to avoid
  this.
- **Package name collisions**: The output name `alacritty` could conflict with
  packages from `pkgs-by-name-for-flake-parts` (configured in `pkgs.nix` with
  `pkgsDirectory = rootPath + "/pkgs/by-name"`). Currently there is no
  `pkgs/by-name/alacritty/` so no collision exists, but future wrapped features
  should be checked against existing package names.

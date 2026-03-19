# Lix Integration

This repository uses [Lix](https://lix.systems), a community fork of the Nix
package manager, as its primary evaluator. This document covers the
configuration, known edge cases, and compatibility considerations.

## Configuration

### System-level

Lix is configured via the
[lix-module](https://git.lix.systems/lix-project/nixos-module) flake input,
which provides NixOS and Darwin modules:

- **NixOS**: `inputs.lix-module.nixosModules.default`
- **Darwin**: `inputs.lix-module.darwinModules.default`

These are imported in `modules/core/nix/lix.nix` and set `nix.package` to Lix on
all hosts.

### Flake inputs

The `lix` input is a non-flake source pin, and `lix-module` follows it:

```nix
lix = {
  url = "github:lix-project/lix";
  flake = false;
};

lix-module = {
  url = "git+https://git.lix.systems/lix-project/nixos-module?ref=main";
  inputs = {
    nixpkgs.follows = "nixpkgs-unstable";
    lix.follows = "lix";
  };
};
```

## Edge Cases

### Experimental feature naming: `pipe-operator` vs `pipe-operators`

Lix and Nix use different names for the pipe operator experimental feature:

| Evaluator | Feature name | | --------- | -------------- | | Lix |
`pipe-operator` | | Nix | `pipe-operators` |

Since `nixConfig` in `flake.nix` must be a static attrset (no `let`, `if`, or
`builtins` expressions), we cannot conditionally select the correct name. The
flake uses the Lix name (`pipe-operator`). When evaluated by stock Nix, this
produces a harmless warning:

```
warning: unknown experimental feature 'pipe-operator'
```

The `.envrc` handles this by detecting the evaluator at shell activation time
and passing the correct flag:

```bash
if nix eval --expr 'builtins.compareVersions builtins.nixVersion "2.90" >= 0' \
    2>/dev/null | grep -q "true"; then
  PIPE_FLAG="pipe-operator"
else
  PIPE_FLAG="pipe-operators"
fi
use flake . --accept-flake-config --impure --extra-experimental-features "$PIPE_FLAG"
```

### Colmena and nix-eval-jobs

Colmena invokes `nix-eval-jobs` internally for evaluation. The colmena package
from the flake input bundles stock Nix's `nix-eval-jobs` by default, which does
not understand Lix-specific features (e.g., `pipe-operator`).

To fix this, the devshell overrides colmena's `nix-eval-jobs` dependency with
the Lix-compatible version from `lixPackageSets`:

```nix
# modules/flake-parts/colmena.nix
colmena = inputs'.colmena.packages.colmena.override {
  nix-eval-jobs = pkgs.lixPackageSets.stable.nix-eval-jobs;
};
```

This requires the `lix-module.overlays.default` overlay to be applied to `pkgs`
(done in `modules/flake-parts/pkgs.nix`) so that `lixPackageSets` is available.

**Important**: Do not replace colmena entirely with `pkgs.colmena` (the nixpkgs
version). The hive is built with `inputs.colmena.lib.makeHive`, and schema
versions must match between the library and the CLI binary. Always override the
flake input's package rather than substituting a different colmena build.

### Deprecated feature warnings from upstream

Several upstream dependencies use deprecated Nix language features that produce
warnings under Lix. These are silenced in `nixConfig`:

```nix
extra-deprecated-features = [
  "or-as-identifier"    # nixpkgs lib.or, nix-filter
  "broken-string-escape" # pyproject-nix (via nixhelm), deploy-rs legacy
];
```

| Warning | Source | Fixable locally? | | --------------------------- |
------------------------------- | ---------------- | | `or` as identifier |
nixpkgs `lib/trivial.nix` | No | | `or` as identifier | nix-filter (via
hyprland) | No | | `\.` broken string escape | pyproject-nix (via nixhelm) | No
|

These are all in upstream code. The `extra-deprecated-features` flags are the
correct way to silence them until upstream fixes land.

### Reducing duplicate nixpkgs-lib / flake-parts copies

Many flake inputs bring their own copy of `flake-parts` and `nixpkgs-lib`, which
can cause duplicate `lib.or` warnings and bloat the lock file. Use `follows`
declarations to deduplicate:

```nix
nix-gaming = {
  url = "github:fufexan/nix-gaming";
  inputs = {
    flake-parts.follows = "flake-parts";
    nixpkgs.follows = "nixpkgs-unstable";
  };
};
```

Inputs with `flake-parts.follows` configured in this repo:

- `ayugram-desktop`
- `nix-cachyos-kernel`
- `nix-gaming`
- `nix-topology`
- `nixcord`
- `nixos-anywhere`
- `statix`

## Detecting Lix vs Nix at runtime

Lix versions start at 2.90+, while Nix is in the 2.2x range. You can detect the
evaluator in Nix expressions or shell scripts:

**Nix expression:**

```nix
builtins.compareVersions builtins.nixVersion "2.90" >= 0
```

**Shell:**

```bash
nix eval --expr 'builtins.compareVersions builtins.nixVersion "2.90" >= 0' \
  2>/dev/null | grep -q "true"
```

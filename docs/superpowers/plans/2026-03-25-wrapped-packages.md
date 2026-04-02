# Wrapped Packages Implementation Plan

> **For agentic workers:** REQUIRED: Use
> superpowers-extended-cc:subagent-driven-development (if subagents available)
> or superpowers-extended-cc:executing-plans to implement this plan. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the `alacritty` feature as a standalone `nix run .#alacritty`
package via the nix-wrapper-modules HM adapter.

**Architecture:** A new flake-parts module reads
`config.features.alacritty.home` (a deferred HM module), passes it to
`wlib.wrapHomeModule` from our nix-wrapper-modules fork, and outputs the
resulting derivation as `perSystem.packages.alacritty`.

**Tech Stack:** Nix, flake-parts, nix-wrapper-modules (HM adapter), home-manager

**Spec:** `docs/superpowers/specs/2026-03-25-wrapped-packages-design.md`

---

### Task 1: Add nix-wrapper-modules flake input

**Goal:** Add `nix-wrapper-modules` as a flake input pointing to our fork.

**Files:**

- Modify: `flake.nix:58-85` (inputs section, "forks we maintain" block)

**Acceptance Criteria:**

- [ ] `nix-wrapper-modules` input exists in `flake.nix`
- [ ] `inputs.nixpkgs.follows` points to `nixpkgs-unstable`
- [ ] `nix flake lock --update-input nix-wrapper-modules` succeeds

**Verify:**
`nix flake metadata --json | jq '.locks.nodes["nix-wrapper-modules"].locked.owner'`
→ `"sini"`

**Steps:**

- [ ] **Step 1: Add the input to flake.nix**

Add within the "Things we maintain forks of..." section (after
`agenix-rekey-to-sops`, before the `# End forks we maintain...` comment):

```nix
nix-wrapper-modules = {
  url = "github:sini/nix-wrapper-modules";
  inputs.nixpkgs.follows = "nixpkgs-unstable";
};
```

- [ ] **Step 2: Lock the new input**

Run: `nix flake lock --update-input nix-wrapper-modules` Expected: Lock file
updated, no errors.

- [ ] **Step 3: Verify the input resolves and exposes the expected API**

Run:
`nix flake metadata --json | jq '.locks.nodes["nix-wrapper-modules"].locked.owner'`
Expected: `"sini"`

Run:
`nix eval --impure --expr '(builtins.getFlake (toString ./.)).inputs.nix-wrapper-modules.lib ? wrapHomeModule'`
Expected: `true`

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat: add nix-wrapper-modules flake input"
```

---

### Task 2: Create wrapped-packages flake-parts module

**Goal:** Create the flake-parts module that wraps `alacritty` and exposes it as
`packages.<system>.alacritty`.

**Files:**

- Create: `modules/flake-parts/features/wrapped-packages.nix`

**Acceptance Criteria:**

- [ ] `nix eval .#packages.x86_64-linux.alacritty.name` returns a derivation
      name containing "alacritty"
- [ ] `nix build .#alacritty` produces a `result/bin/alacritty` wrapper script
- [ ] The wrapper derivation contains alacritty config under
      `result/hm-xdg-config/`

**Verify:**
`nix build .#alacritty && file result/bin/alacritty && find result/ -name 'alacritty.toml'`
→ wrapper script exists, config file found

**Steps:**

- [ ] **Step 1: Create the module file**

Create `modules/flake-parts/features/wrapped-packages.nix`:

```nix
{ inputs, config, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      wlib = inputs.nix-wrapper-modules.lib;

      # Static registry of features to wrap as standalone packages.
      # Each entry maps a package output name to its wrapping config.
      # Only Tier 1 features (no user/host/environment context) belong here.
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

This file is auto-imported by `import-tree ./modules` — no manual import needed.

- [ ] **Step 2: Build and verify the wrapper**

Run: `nix build .#alacritty` Expected: Build succeeds, `result/` symlink
created.

Run: `file result/bin/alacritty` Expected: Output indicates a shell script or
wrapper (not an ELF binary directly).

Run: `find result/ -name 'alacritty.toml' -o -name 'alacritty.yml' 2>/dev/null`
Expected: Config file found under `result/hm-xdg-config/alacritty/` or
`result/hm-home/`.

- [ ] **Step 3: Verify no collisions with existing packages**

Run: `nix eval .#packages.x86_64-linux --apply 'builtins.attrNames' --json | jq`
Expected: `alacritty` appears in the list without errors.

- [ ] **Step 4: Commit**

```bash
git add modules/flake-parts/features/wrapped-packages.nix
git commit -m "feat: add wrapped-packages module with alacritty pilot"
```

---

### Task 3: Verify flake integrity

**Goal:** Confirm the new module doesn't break existing host builds or flake
checks.

**Files:**

- None (verification only)

**Acceptance Criteria:**

- [ ] `nix flake check` passes (or has only pre-existing warnings)
- [ ] `nix-flake-build cortex` still succeeds
- [ ] `nix run .#alacritty` launches alacritty

**Verify:** `nix flake check` → no new errors; `nix run .#alacritty` → alacritty
window opens

**Steps:**

- [ ] **Step 1: Run flake check**

Run: `nix flake check` Expected: No new errors. Pre-existing warnings are
acceptable.

- [ ] **Step 2: Build an existing host**

Run: `nix-flake-build cortex` Expected: Build succeeds without regressions.

- [ ] **Step 3: Inspect the generated config**

Run:
`nix build .#alacritty && cat "$(find result/ -name 'alacritty.toml' | head -1)"`
Expected: Contains `live_config_reload = true`, `decorations = "full"`,
`title = "Terminal"`, bell settings.

- [ ] **Step 4: Run the wrapped alacritty (requires graphical session)**

Run: `nix run .#alacritty` Expected: Alacritty opens with our configured
settings.

Alternative headless verification: Run: `cat result/bin/alacritty` Expected:
Wrapper script that sets `XDG_CONFIG_HOME` and execs the real alacritty binary.

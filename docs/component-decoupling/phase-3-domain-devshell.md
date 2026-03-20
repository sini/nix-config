# Phase 3 — Domain-contributed devshell and pre-commit (Issues 6, 7)

**Status**: TODO

**Goal**: Let each domain own its devshell commands and pre-commit hooks.

## Issues

### Issue 6 — Kubernetes pre-commit hook in devtools

**File**: `devtools/pre-commit.nix` lines ~45–52

The `k8s-update-manifests` hook is kubernetes-domain logic (trigger pattern,
command, purpose) living in the devtools domain. Kubernetes workflow changes
require editing a devtools file.

### Issue 7 — Domain-specific commands in devshell

**File**: `devtools/devshell.nix` lines ~45–115

Contains `toggle-axon-kubernetes`, `list-infra`, host provisioning commands, and
k8s manifest commands — operational tooling for specific domains mixed with
general development tools.

## Steps

1. Use the flake-parts option system to let domains contribute:
   - Each domain module appends to `devshells.default.commands` (already
     supported by numtide/devshell).
   - Each domain module appends to `pre-commit.settings.hooks`.
2. Move kubernetes commands from `devtools/devshell.nix` to `kubernetes/`
   (contributing via the devshell option).
3. Move `k8s-update-manifests` hook from `devtools/pre-commit.nix` to
   `kubernetes/`.
4. Move host provisioning commands from `devtools/devshell.nix` to `hosts/`.
5. Move infrastructure listing commands to `environments/`.
6. `devtools/devshell.nix` retains only general development tools (git, nix,
   formatters, linters).
7. `devtools/pre-commit.nix` retains only generic hooks (treefmt, statix).
8. Verify: `nix develop` and `pre-commit run --all-files`.

## Risk

Low — devshell commands are additive. The main risk is ordering or naming
conflicts.

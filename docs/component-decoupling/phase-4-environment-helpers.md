# Phase 4 — Extract environment cross-domain helpers (Issue 5)

**Status**: TODO

**Goal**: Make domain boundary crossings in environments explicit.

## Issue 5 — Environment helpers cross domain boundaries

**File**: `environments/options.nix` lines ~444–539

Computed readOnly options `findHostsByRole` and `groups` query the hosts and
users/groups domains respectively. While read-only, they embed cross-domain
queries inside the environment type definition.

## Steps

1. Create `environments/helpers.nix` exposing `flake.lib.environment-helpers`.
2. Move `findHostsByRole` and `groups` from the `config` block of
   `environments/options.nix` into `environments/helpers.nix` as standalone
   functions that accept their dependencies as parameters.
3. In `environments/options.nix`, define the readOnly computed options by calling
   the extracted helpers with explicit inputs (`config.hosts`, `config.groups`).
4. Verify: `nix eval .#environments`.

## Risk

Low — the helpers are readOnly computed values. Extracting them does not change
evaluation behavior.

# Phase 5 — Minor cleanups (Issues 8, 9, 10)

**Status**: TODO

**Goal**: Address remaining low-severity items.

## Issue 8 — Monitoring/exporter logic in hosts domain

**File**: `hosts/utils.nix` lines ~18–52

`getAutoExporters` hard-codes monitoring port assignments (`node:9100`,
`k3s-server:10249`, `etcd:2381`) based on role membership. This is a monitoring
concern, not a host configuration concern.

**Action**: Move to a monitoring helper or let roles declare their exporters via
the role submodule type. Evaluate whether a dedicated `monitoring/` domain
folder is warranted or if this fits better as a role-level concern in
`features/roles.nix`.

## Issue 9 — Duplicate feature submodule shape

**Files**: `features/options.nix` and `features/helpers.nix`

Both files define the feature submodule structure
(requires/excludes/system/linux/darwin/home).

**Action**: Consolidate. Have `features/options.nix` reference the canonical
shape from `features/helpers.nix` rather than redefining it.

## Issue 10 — expose-options.nix manually lists domains

**File**: `expose-options.nix` lines ~19–27

Hard-codes which domain options to re-export as flake outputs.

**Action**: Evaluate auto-discovery. If the list of exposed options is stable,
the manual approach is acceptable. If domains are expected to grow, switch to a
pattern where each domain registers its exportable options.

## Risk

Low.

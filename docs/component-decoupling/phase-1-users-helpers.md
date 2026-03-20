# Phase 1 — Create `users/helpers.nix` (Issues 1, 2)

**Status**: DONE

**Goal**: Give the users domain its own logic layer by consolidating all
user-related helpers — type builders, group resolution, and ACL-based user
resolution.

## Data flow context

User resolution is a 3-layer merge with ACL gating:

```
┌─────────────────┐   ┌──────────────────┐   ┌─────────────────┐
│ users/<name>     │   │ environments     │   │ hosts/<name>    │
│   .identity      │   │   .<env>.users   │   │   .users        │
│   .system        │   │   .<env>.access  │   │   .system-      │
│                  │   │   .<env>.system-  │   │    access-groups│
│ (canonical)      │   │    access-groups  │   │ (host override) │
└────────┬─────────┘   └────────┬─────────┘   └────────┬────────┘
         │                      │                       │
         └──────────┬───────────┘───────────────────────┘
                    │
         ┌──────────▼──────────┐
         │   resolveUser()     │
         │                     │
         │ 1. identity: from   │
         │    canonical user   │
         │                     │
         │ 2. system fields:   │    ┌────────────────────┐
         │    canonical base   │    │ groups/<name>       │
         │    → env override   │    │   .labels           │
         │    → host override  │    │   .members          │
         │    (first non-null  │    │                     │
         │     wins)           │    │ (shared definitions)│
         │                     │    └────────┬────────────┘
         │ 3. ACL:             │             │
         │    env.access gives ◄─────────────┘
         │    direct groups    │
         │    → transitive     │
         │      membership via │
         │      group.members  │
         │    → filter by      │
         │      label          │
         │                     │
         │ 4. enable:          │
         │    user-role groups  │
         │    ∩ merged system-  │
         │    access-groups     │
         │    (env + host)     │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │  Resolved user      │
         │   .identity         │
         │   .system.enable    │
         │   .system.uid/gid   │
         │   .system.linger    │
         │   .system.*features │
         │   .systemGroups     │
         │   .resolvedGroups   │
         │   .groupsByLabel()  │
         └─────────────────────┘
```

The `coalesce` pattern for system field merging: host override → env override →
canonical base. First non-null value wins. `uid`/`gid` are exceptions — they
come only from canonical, never overridden.

## What was moved to `users/helpers.nix`

**Type builders** (from `features/helpers.nix`):

| Function | Purpose | Consumers |
| --- | --- | --- |
| `identitySubmoduleType` | Submodule type for user identity (displayName, email, sshKeys, gpgKey) | `users/options.nix`, `mkEnvUsersOpt` |
| `mkEnvUsersOpt` | Environment-level user options (nullable overrides + derived identity) | `environments/options.nix` |
| `mkHostUsersOpt` | Host-level user options (all nullable overrides) | `hosts/options.nix` |

**Resolution logic** (from `hosts/configuration-helpers.nix` Section 2):

| Function | Purpose | Consumers |
| --- | --- | --- |
| `coalesce` | First non-null value helper | `resolveUser` |
| `resolveGroupMembership` | Transitive group traversal via `group.members` reverse lookup | `resolveUser` |
| `resolveUser` | Full 3-layer merge + ACL resolution for one user | `resolveUsers` |
| `resolveUsers` | Batch resolution — union of canonical + env.access + env.users + host.users | `prepareHostContext` in hosts |

## What stayed in place

**In hosts**: `makeHomeConfig` (resolved user → home-manager modules),
`prepareHostContext` (orchestration), `mkNixosHost`/`mkDarwinHost`/`mkHost`
(builders).

**In features**: `mkDeferredModuleOpt`, `mkFeatureNameOpt`,
`featureSubmoduleGenericOptions`, `collect*Modules`, `collectRequires`,
`getFeaturesForRoles`, `getModulesForFeatures`, `computeActiveFeatures`.

## Changes made

| File | Action |
|---|---|
| `users/helpers.nix` | Created — `flake.lib.users` with 7 functions |
| `features/helpers.nix` | Removed 3 user type builders from let block and exports |
| `hosts/configuration-helpers.nix` | Removed Section 2 (~150 lines), added `inherit (self.lib.users) resolveUsers` |
| `users/options.nix` | `self.lib.modules` → `self.lib.users` for `identitySubmoduleType` |
| `environments/options.nix` | `self.lib.modules` → `self.lib.users` for `mkEnvUsersOpt` |
| `hosts/options.nix` | Split inherit: `mkDeferredModuleOpt` from modules, `mkHostUsersOpt` from users |

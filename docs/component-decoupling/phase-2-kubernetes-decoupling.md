# Phase 2 — Decouple kubernetes from environments and hosts (Issues 3, 4)

**Status**: TODO

**Goal**: Remove hard coupling between the kubernetes, environments, and hosts
domains by inverting the dependency direction for Issue 3 and making implicit
dependencies explicit for Issue 4.

## Issue 3 — Kubernetes config type coupled into environments

### Current state

`environments/options.nix` pulls `kubernetesConfigType` from the kubernetes
domain:

```nix
# environments/options.nix lines 11, 222-226
inherit (self.lib.kubernetes-services) kubernetesConfigType;
# ...
kubernetes = mkOption {
  type = kubernetesConfigType;
  default = { };
  description = "Kubernetes-specific network configuration";
};
```

This creates a hard dependency: environments cannot be evaluated without
kubernetes types being available. The environments domain must know about
kubernetes internals.

### Dependency graph (current)

```
environments/options.nix
  └── imports kubernetesConfigType from kubernetes/service-helpers.nix
```

### Proposed fix — kubernetes injects into environments

Use the NixOS module system's submodule merging to let kubernetes extend the
environment type. When two modules declare the same option with compatible
submodule types, the module system merges their definitions.

```
kubernetes/environment-extension.nix  (NEW)
  └── extends options.environments with kubernetes option

environments/options.nix
  └── no kubernetes knowledge
```

### Implementation

1. **Create `kubernetes/environment-extension.nix`**:

   ```nix
   { self, lib, ... }:
   let
     inherit (lib) mkOption types;
     inherit (self.lib.kubernetes-services) kubernetesConfigType;
   in
   {
     options.environments = mkOption {
       type = types.attrsOf (types.submodule {
         options.kubernetes = mkOption {
           type = kubernetesConfigType;
           default = { };
           description = "Kubernetes-specific configuration for this environment";
         };
       });
     };
   }
   ```

   The module system merges this submodule definition with the one in
   `environments/options.nix`. The `kubernetes` option appears on every
   environment instance without `environments/options.nix` knowing about it.

1. **Update `environments/options.nix`**:
   - Remove `inherit (self.lib.kubernetes-services) kubernetesConfigType;` (line
     11).
   - Remove the `kubernetes` option declaration (lines 222–226).
   - The `config.secrets.oidcIssuerFor` block (lines 514–539) references
     `config.kubernetes.sso.*`. After the move, this still works — the option is
     still present on the environment submodule, just declared by a different
     module.

1. **Verify**: `nix eval .#environments` should return the same structure.

### Risk

**Low**. The module system's submodule merging is a standard pattern used
throughout NixOS. The only requirement is that the `options.environments` option
type is compatible — both declarations use
`types.attrsOf (types.submodule ...)`, which merges cleanly.

**Edge case**: If `environments/options.nix` uses a named `environmentType`
variable (it does — `types.attrsOf environmentType`), the merge still works
because `environmentType` is `types.submodule (...)` and the extension adds
another `types.submodule { ... }`. The module system combines submodule
definitions from all sources.

---

## Issue 4 — Nixidy helpers reach into hosts domain

### Current state

`kubernetes/nixidy-helpers.nix` accesses `config.flake.hosts` directly in the
`mkEnv` function:

```nix
# kubernetes/nixidy-helpers.nix line 218-221
extraSpecialArgs = {
  inherit environment inputs;
  inherit (config.flake) hosts;    # <-- implicit dependency on hosts domain
  crdObjects = serviceCrdObjects;
};
```

This means:

- `mkEnv` cannot be tested without a fully evaluated hosts config.
- The dependency is invisible from the function signature — `mkEnv` takes
  `{ system, pkgs, env, environment }` but secretly also needs `hosts`.

### Dependency graph (current)

```
kubernetes/nixidy-helpers.nix
  └── mkEnv reads config.flake.hosts (implicit)
      └── kubernetes/nixidy-envs.nix calls mkEnv (unaware of hosts dep)
```

### Proposed fix — explicit parameter

Add `hosts` as a parameter to `mkEnv`. The caller (`nixidy-envs.nix`) passes it
explicitly.

```
kubernetes/nixidy-envs.nix
  └── passes config.hosts to mkEnv (explicit)
      └── kubernetes/nixidy-helpers.nix
          └── mkEnv uses hosts param (no config.flake access)
```

### Implementation

1. **Update `kubernetes/nixidy-helpers.nix`** — add `hosts` to `mkEnv` params:

   ```nix
   mkEnv =
     {
       system,
       pkgs,
       env,
       environment,
       hosts,          # <-- new explicit parameter
     }:
     let
       # ...
     in
     inputs.nixidy.lib.mkEnv {
       inherit pkgs;
       charts = (inputs.nixhelm.chartsDerivations.${system} or { }) // userCharts;
       extraSpecialArgs = {
         inherit environment inputs hosts;    # <-- use param instead of config.flake
         crdObjects = serviceCrdObjects;
       };
       # ...
     };
   ```

   Remove `inherit (config.flake) hosts;` from `extraSpecialArgs`.

1. **Update `kubernetes/nixidy-envs.nix`** — pass `hosts` from caller:

   ```nix
   mkEnv {
     inherit system pkgs env environment;
     hosts = config.hosts;                   # <-- explicit pass
   }
   ```

   Note: `nixidy-envs.nix` already has `config` in scope (flake-parts module
   args), and `config.hosts` is the canonical hosts option. Using `config.hosts`
   rather than `config.flake.hosts` is more direct — `config.flake.hosts` is
   just a re-export from `expose-options.nix`.

1. **Verify**: `nix eval .#nixidyEnvs` should produce identical output.

### Risk

**Low**. This is a pure parameter threading change — no logic changes. The only
risk is missing a call site, but `mkEnv` has exactly one caller
(`nixidy-envs.nix`).

### Additional observation

`kubernetes/nixidy-helpers.nix` also references `config.flake.meta.repo` (line
11\) and `config.features.agenix-generators.system` (line 229). These are
lower-priority cross-domain reads:

- `meta.repo` is stable metadata unlikely to cause issues.
- `agenix-generators` is a feature-domain reference used to inject secret
  handling into nixidy modules. This could be parameterized in a future phase
  but is not blocking.

---

## Steps (combined)

1. Create `kubernetes/environment-extension.nix` — injects `kubernetes` option
   into environments.
1. Update `environments/options.nix` — remove `kubernetesConfigType` import and
   `kubernetes` option.
1. Update `kubernetes/nixidy-helpers.nix` — add `hosts` param to `mkEnv`, remove
   `config.flake.hosts` reference.
1. Update `kubernetes/nixidy-envs.nix` — pass `hosts = config.hosts` to `mkEnv`.
1. Verify:
   ```bash
   nix eval .#environments --apply 'e: builtins.attrNames e'
   nix eval .#lib --apply 'lib: builtins.attrNames lib'
   nix eval .#hosts --apply 'h: builtins.attrNames h'
   nix flake check --no-build
   ```

## Overall risk

**Low-Medium**. Both changes are mechanical — no logic changes, just moving
where types are declared and making implicit dependencies explicit. The module
system submodule merging pattern is well-established in NixOS.

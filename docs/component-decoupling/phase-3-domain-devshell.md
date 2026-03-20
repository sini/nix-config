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

**File**: `devtools/devshell.nix` lines ~31–116

Contains `toggle-axon-kubernetes`, `list-infra`, host provisioning commands, and
k8s manifest commands — operational tooling for specific domains mixed with
general development tools.

## Mechanism

The `devshells.default.commands` option (from numtide/devshell) is a list that
merges across modules — any flake-parts module can append to it. Similarly,
`pre-commit.settings.hooks` is an attrset that merges across modules (the
`inputs.git-hooks-nix.flakeModule` import in `devtools/pre-commit.nix` makes it
available globally).

Each domain creates a `devshell.nix` that contributes its commands via the
perSystem section. No new options or conventions needed — just use the existing
merge behavior.

## Command categorization

All packages are defined in `pkgs/by-name/` and auto-discovered. The devshell
just registers them as named commands.

### Stays in `devtools/devshell.nix` — generic dev tools

| Command | Reason | |---|---| | `nh` | Nix helper | | `treefmt` | Formatter | |
`nix-tree` | Derivation browser | | `nvd` | Nix diff | | `nix-diff` | Explain
derivation differences | | `nix-output-monitor` | Build monitoring | |
`nix-flake-build` | Build any host config | | `nix-flake-update` | Update flake
inputs | | `list-infra` | Cross-cutting overview tool |

### Moves to `kubernetes/devshell.nix` — kubernetes operations

| Command | Current location | Reason | |---|---|---| | `toggle-axon-kubernetes`
| `devtools/devshell.nix` | K8s cluster management | | `convert-oidc-secrets` |
`devtools/devshell.nix` | OIDC is k8s service auth | | `k8s-update-manifests`
(command) | `kubernetes/nixidy-envs.nix` | Consolidate k8s devshell | |
`k8s-update-manifests` (pre-commit) | `devtools/pre-commit.nix` | K8s manifest
regeneration |

### Moves to `hosts/devshell.nix` — host provisioning

| Command | Reason | |---|---| | `update-host-keys` | Host SSH key management |
| `nix-flake-provision-keys` | Host key provisioning | | `nix-flake-install` |
Remote NixOS installation | | `impermanence-copy` | Host persistent storage | |
`update-tang-disk-keys` | Host disk encryption |

### Moves to `secrets/devshell.nix` — secrets management

| Command | Reason | |---|---| | `generate-vault-certs` | Vault certificate
generation | | `generate-user-keys` | User SSH key generation + encryption |

## Steps

### 1. Create `kubernetes/devshell.nix`

```nix
{ ... }:
{
  perSystem =
    { config, ... }:
    {
      devshells.default.commands = [
        {
          package = config.packages.k8s-update-manifests;
          name = "k8s-update-manifests";
          help = "Update Kubernetes manifests for nixidy environments";
        }
        {
          package = config.packages.toggle-axon-kubernetes;
          name = "toggle-axon-kubernetes";
          help = "Toggle enable/disable Kubernetes on axon cluster nodes";
        }
        {
          package = config.packages.convert-oidc-secrets;
          name = "convert-oidc-secrets";
          help = "Convert age-encrypted OIDC secrets to SOPS-encrypted YAML format";
        }
      ];

      pre-commit.settings.hooks.k8s-update-manifests = {
        enable = true;
        name = "k8s-update-manifests";
        description = "Run k8s-update-manifests to re-generate argocd config";
        entry = "${config.packages.k8s-update-manifests}/bin/k8s-update-manifests --skip-secrets";
        files = "^(flake\\.lock|modules/(environments|flake-parts|lib|kubernetes)/.*\\.nix)$";
        pass_filenames = false;
      };
    };
}
```

### 2. Create `hosts/devshell.nix`

```nix
{ ... }:
{
  perSystem =
    { config, ... }:
    {
      devshells.default.commands = [
        {
          package = config.packages.update-host-keys;
          name = "update-host-keys";
          help = "Collect and encrypt SSH host keys from all configured hosts";
        }
        {
          package = config.packages.nix-flake-provision-keys;
          name = "nix-flake-provision-keys";
          help = "Provision SSH host keys and disk encryption secrets for a NixOS host";
        }
        {
          package = config.packages.nix-flake-install;
          name = "nix-flake-install";
          help = "Install NixOS remotely using nixos-anywhere with SSH keys and disk encryption";
        }
        {
          package = config.packages.impermanence-copy;
          name = "impermanence-copy";
          help = "Copy existing data to impermanence persistent storage for a host";
        }
        {
          package = config.packages.update-tang-disk-keys;
          name = "update-tang-disk-keys";
          help = "Update disk encryption keys using Tang servers and TPM2";
        }
      ];
    };
}
```

### 3. Create `secrets/devshell.nix`

```nix
{ ... }:
{
  perSystem =
    { config, ... }:
    {
      devshells.default.commands = [
        {
          package = config.packages.generate-vault-certs;
          name = "generate-vault-certs";
          help = "Generate certificates for Vault raft cluster";
        }
        {
          package = config.packages.generate-user-keys;
          name = "generate-user-keys";
          help = "Generate and encrypt ed25519 SSH keys for users";
        }
      ];
    };
}
```

### 4. Update `devtools/devshell.nix`

Remove all domain-specific commands. Retain only:

- Packages: git, gh, nix, nixos-rebuild, nix-output-monitor, nix-fast-build,
  nil, nixd, sops (+ coreutils on Darwin)
- Commands: nh, treefmt, nix-tree, nvd, nix-diff, nix-output-monitor,
  nix-flake-build, nix-flake-update, list-infra
- pre-commit startup hook

### 5. Update `devtools/pre-commit.nix`

Remove the `k8s-update-manifests` hook. Retain only: treefmt, statix.

### 6. Update `kubernetes/nixidy-envs.nix`

Remove the `devshells.default.commands` block (the k8s-update-manifests command
is now in `kubernetes/devshell.nix`).

### 7. Verify

```bash
nix eval .#lib --apply 'lib: builtins.attrNames lib'
nix eval .#hosts --apply 'h: builtins.attrNames h'
nix eval .#environments --apply 'e: builtins.attrNames e'
nix flake check --no-build
nix develop --command true
```

## Risk

**Low**. All changes are additive list/attrset merges via the module system. The
devshell command order may shift but has no functional impact. The pre-commit
hook behavior is identical — only the declaring module changes.

**Key invariant**: The `inputs.git-hooks-nix.flakeModule` import stays in
`devtools/pre-commit.nix`. It only needs to be imported once — after that, any
module can contribute `pre-commit.settings.hooks.*`.

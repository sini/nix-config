# Component Decoupling Plan

After restructuring `modules/flake-parts/` into domain-based folders, this plan
addresses remaining cross-contamination where logic or types bleed across domain
boundaries.

## Current Layout

```
modules/flake-parts/
├── hosts/                  # Host options, configuration builders, colmena, build targets
├── kubernetes/             # K8s service types, nixidy, helm charts, OCI images
├── features/               # Feature module types, helpers, roles
├── users/                  # User options, group options, helpers
├── environments/           # Environment options
├── secrets/                # Secrets paths, agenix-rekey
├── devtools/               # Devshell, treefmt, pre-commit, flake-root
├── channels.nix
├── expose-options.nix
├── files.nix
├── flake-parts.nix
├── lib-module.nix
├── meta.nix
├── pkgs.nix
├── systems.nix
└── text.nix
```

## Issues

| # | Issue | Severity | File(s) | Phase |
|---|-------|----------|---------|-------| | 1 | User/ACL resolution logic in
hosts domain | HIGH | `hosts/configuration-helpers.nix` |
[1](phase-1-users-helpers.md) | | 2 | User type builders in features domain |
HIGH | `features/helpers.nix` | [1](phase-1-users-helpers.md) | | 3 | Kubernetes
config type coupled into environments | MEDIUM | `environments/options.nix` |
[2](phase-2-kubernetes-decoupling.md) | | 4 | Nixidy helpers reach into hosts
domain | MEDIUM | `kubernetes/nixidy-helpers.nix` |
[2](phase-2-kubernetes-decoupling.md) | | 5 | Environment helpers cross domain
boundaries | MEDIUM | `environments/options.nix` |
[4](phase-4-environment-helpers.md) | | 6 | Kubernetes pre-commit hook in
devtools | MEDIUM | `devtools/pre-commit.nix` | [3](phase-3-domain-devshell.md)
| | 7 | Domain-specific commands in devshell | LOW-MEDIUM |
`devtools/devshell.nix` | [3](phase-3-domain-devshell.md) | | 8 |
Monitoring/exporter logic in hosts domain | LOW-MEDIUM | `hosts/utils.nix` |
[5](phase-5-minor-cleanups.md) | | 9 | Duplicate feature submodule shape | LOW |
`features/options.nix`, `features/helpers.nix` | [5](phase-5-minor-cleanups.md)
| | 10 | expose-options.nix manually lists domains | LOW | `expose-options.nix`
| [5](phase-5-minor-cleanups.md) |

## Phase Summary

| Phase | Issues | Impact | Risk | Status | | ----- | ------ | ------ | ---- |
------ | | [1](phase-1-users-helpers.md) | 1, 2 | HIGH — establishes users as a
proper domain | Medium | DONE | | [2](phase-2-kubernetes-decoupling.md) | 3, 4 |
MEDIUM — removes hard coupling between kubernetes, environments, hosts |
Low-Medium | | | [3](phase-3-domain-devshell.md) | 6, 7 | MEDIUM — each domain
owns its tooling contributions | Low | | | [4](phase-4-environment-helpers.md) |
5 | LOW — remove dead `groups` helper; `findHostsByRole` is acceptable | None |
DECLINED | | [5](phase-5-minor-cleanups.md) | 8, 9, 10 | LOW — cleanup and
consolidation | Low | |

## Validation

After each phase, run:

```bash
nix eval .#lib --apply 'lib: builtins.attrNames lib'
nix eval .#hosts --apply 'h: builtins.attrNames h'
nix eval .#environments --apply 'e: builtins.attrNames e'
nix flake check --no-build
```

After phases involving devshell or pre-commit:

```bash
nix develop --command true
nix develop --command pre-commit run --all-files
```

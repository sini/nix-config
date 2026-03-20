# Phase 4 — Environment cross-domain helpers (Issue 5)

**Status**: DECLINED (downgraded to optional cleanup)

**Original goal**: Extract `findHostsByRole` and `groups` into standalone
functions in `environments/helpers.nix` with explicit dependency parameters.

## Analysis

### Helper categorization

The environment submodule's `config` block defines 7 computed readOnly options:

| Helper | Cross-domain? | Consumers | |---|---|---| | `getDomainFor` | No —
reads `config.services`, `config.domain` | Many (k8s services, kanidm, etc.) | |
`domainToResourceName` | No — pure string transform | K8s certificate resources
| | `getTopDomainFor` | No — calls `getDomainFor` | K8s certificate resources |
| `getAssignment` | No — reads `config.networks` | K8s services, NixOS modules |
| `findHostsByRole` | **Yes** — reads `flakeConfig.hosts` | 7 consumers across
services/, kubernetes/, core/ | | `groups` | **Yes** — reads
`flakeConfig.groups` | **0 consumers** | | `secrets.oidcIssuerFor` | Indirect —
reads `config.kubernetes.sso.*` (injected by k8s) | K8s OIDC services |

### Why extraction doesn't help

The original plan was to move `findHostsByRole` and `groups` to standalone
functions that take their dependencies as explicit parameters. This would:

1. **Not reduce coupling** — the cross-domain read still happens, just in a
   different file.
1. **Worsen ergonomics** — consumers currently call
   `environment.findHostsByRole "k3s"` directly. With extraction, they'd need
   access to a lib function plus the hosts config to pass as a parameter.
1. **Break the submodule pattern** — readOnly computed options on a submodule
   are the idiomatic NixOS way to expose derived data. Moving them out fights
   the module system rather than working with it.

### `findHostsByRole` is an acceptable cross-domain read

It filters `flakeConfig.hosts` by role and environment name. This is a read-only
query with clear semantics — it answers "which hosts in _this_ environment have
role X?" The data flows one direction (hosts → environment helper) and the
helper is consumed by NixOS modules that already receive `environment` via
`specialArgs`.

### `groups` is dead code

Zero consumers outside its own doc comment. It can be removed.

## Recommended action

1. **Remove `groups` helper** — dead code, no consumers.
1. **Leave everything else as-is** — the remaining helpers are either
   self-referential or acceptable cross-domain reads.
1. No `environments/helpers.nix` file needed.

## Risk

None — removing unused code only.

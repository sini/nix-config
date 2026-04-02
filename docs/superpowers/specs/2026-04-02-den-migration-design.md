# Den Migration Design

## Overview

Migrate the nix-config repository from its custom flake-parts module system to
den, an aspect-oriented, context-driven configuration framework for Nix. Den
replaces the custom option types, feature resolver, host builder, and user
provisioning logic with a declarative context pipeline and composable aspects.

## Context Pipeline

The core architectural decision: six entity types map to den's context system as
either context stages, aspects, or schema data.

### Pipeline Topology

```
den.ctx.environment { env }
  |-- into.host  -> { host }              # host.environment = resolved env
  |   '-- into.user -> { host, user }     # den built-in, env via host.environment
  '-- into.cluster -> { cluster }          # cluster.environment = resolved env
      '-- into.k8s-service -> { cluster, service }
```

Environment is the entry point. It fans out into hosts (from its resolved host
membership) and clusters (from its resolved cluster membership). Environment data
propagates downstream via `host.environment` and `cluster.environment` — not as a
separate context parameter.

Host-to-user uses den's built-in transition. User-scoped aspects access
environment data via `host.environment`.

Cluster-to-k8s-service is a parallel branch. Each enabled service receives its
cluster context (and thus `cluster.environment`).

**TODO:** Upstream `take.atLeast` on `ctx.user` (currently `take.exactly`) to
allow `{ env, host, user }` signatures directly, eliminating the need for
`host.environment` indirection.

### Integration with Den's Output Pipeline

Den's output pipeline starts at `den.ctx.flake {}`, which fans out through
`flake-system` into `flake-os` (which creates host contexts). The environment
context stage integrates by overriding `ctx.flake-system.into.flake-os` to route
through environment resolution first:

```nix
# Override the flake-system -> flake-os transition to resolve environments first
den.ctx.flake-system.into.flake-os = { system }:
  let
    # Resolve each environment's hosts for this system
    envHosts = lib.concatMap (env:
      map (host: { inherit host; })
        (lib.filter (h: h.system == system) (lib.attrValues env.resolvedHosts))
    ) (lib.attrValues den.environments);
  in envHosts;
```

The environment context itself is invoked separately for cross-host operations
(service discovery, monitoring targets) and injects resolved data onto hosts
before they enter den's standard host pipeline. Clusters use a parallel context
branch (`ctx.flake-cluster`) that does not pass through `flake-os`.

### Environment Resolution

`host.environment` is a string at definition time (e.g., `"prod"`). Resolution
to a full attrset happens during the `flake-system.into.flake-os` override: the
transition looks up `den.environments.${host.environmentName}` and attaches the
resolved attrset to `host.environment` before the host enters the pipeline.

To avoid circularity (`environment.findHostsByFeature` references hosts, hosts
reference environment), environment helpers that query across hosts receive the
full host set as a closure parameter at resolution time, not via self-reference.

### ACL-Driven User Materialization

ACL resolution runs in a custom override of `ctx.host.into.user`. Den's built-in
transition maps over `host.users`, so the resolved user set must be computed
before the transition fires:

```nix
den.ctx.host.into.user = { host }:
  let
    env = host.environment;
    # Three-level ACL resolution
    gates = lib.unique (env.system-access-groups ++ host.system-access-groups);
    resolvedUsers = lib.filterAttrs (name: user:
      let
        directGroups = env.access.${name} or [];
        transitiveGroups = resolveGroupMembership groups directGroups;
        systemGroups = lib.filter (g: groups.${g}.scope == "system") transitiveGroups;
      in
        lib.intersectLists systemGroups gates != []
    ) canonicalUsers;
  in
    map (user: { inherit host user; }) (lib.attrValues resolvedUsers);
```

This replaces the current `lib.users.resolveUsers` logic with equivalent
resolution inside the den pipeline transition.

### Per-Host/Per-User Aspect Overrides

The current `extra-features` and `excluded-features` on hosts and users control
which features are active. In den, this maps to dynamic `includes` on the host
and user aspects:

```nix
# Host aspect dynamically includes based on host schema
den.aspects.cortex = { host }: {
  includes =
    (map (name: den.aspects.${name}) host.extra-features)
    ++ [ den.aspects.default ];
  # excluded-features handled by filtering includes list
};
```

For user-level overrides, the user aspect similarly reads `user.extra-features`
and `user.excluded-features` to build its includes list. When
`user.include-host-features` is true, the user aspect inherits the host's
resolved aspect includes.

### Type Mapping

| Current Type    | Den Concept                | Rationale                                         |
| --------------- | -------------------------- | ------------------------------------------------- |
| Environment     | Context stage + schema     | Active query scope, fans out to hosts + clusters  |
| Host            | Context stage + schema     | Produces nixosConfigurations/darwinConfigurations  |
| User            | Context stage + schema     | Produces user accounts + home-manager config       |
| Cluster         | Context stage + schema     | Produces k8s/nixidy configurations                |
| K8s Service     | Context stage + schema     | Produces per-service nixidy modules               |
| Feature         | Aspect (1:1)               | Composable config with includes/provides/settings |
| Group           | Top-level option (ACL data)| Consumed during context transitions               |

## Schemas

### `den.schema.environment` (new)

```nix
{
  name                  # environment identifier (prod, dev)
  id                    # numeric environment ID
  domain                # base domain (e.g., "json64.dev")
  secretPath            # path to environment secrets
  networks              # { name -> { cidr, ipv6, gateway, dns, wireless, assignments } }
  email                 # { domain, admin }
  acme                  # certificate server/provider/resolver config
  timezone              # default timezone
  location              # { country, region }
  tags                  # key-value metadata
  certificates          # domain->issuer mappings + issuer configs
  services              # service-specific domain overrides
  delegation            # cross-environment delegation (metricsTo, authTo, logsTo)
  monitoring            # cross-environment scanning config
  settings              # default feature settings for all hosts
  users                 # environment-level user overrides
  access                # ACL mapping: { username -> [groupnames] }
  system-access-groups  # env-wide login gates

  # computed helpers
  getDomainFor          # serviceName -> domain
  getTopDomainFor       # serviceName -> top-level domain
  getAssignment         # name -> IP assignment across networks
  findHostsByFeature    # featureName -> [hosts]
}
```

### `den.schema.host` (extends den built-in)

```nix
{
  environment           # resolved environment attrset
  networking            # interfaces, bridges, bonds, autobridging
  ipv4, ipv6            # derived from managed interfaces
  secretPath            # path to host secrets
  public_key            # SSH host public key path
  facts                 # nixos-facter JSON path
  exporters             # prometheus exporters (port/path/interval)
  system-access-groups  # login gate groups (merged with env)
  system-owner          # primary user
  settings              # per-host feature settings overrides
}
```

### `den.schema.user` (extends den built-in)

```nix
{
  identity              # { displayName, email, sshKeys, gpgKey }
  uid, gid              # deterministic IDs
  linger                # systemd user lingering
  extra-features        # per-user aspect additions
  excluded-features     # per-user aspect exclusions
  include-host-features # inherit all host aspects
  settings              # per-user feature settings
}
```

### `den.schema.cluster` (new)

```nix
{
  name                  # cluster identifier
  environment           # resolved environment attrset
  role                  # feature name for host auto-discovery
  hosts                 # explicit host list or null (role-based)
  resolvedHosts         # computed member hosts
  networks              # { pods, services, loadbalancers } with CIDR, IPv6, assignments
  kubernetes            # { tlsSanIps, sso, services.enabled, services.config }
  secretPath            # path to cluster secrets
  sopsAgeRecipient      # derived from secretPath
}
```

### `den.schema.k8s-service` (new)

```nix
{
  name                  # service identifier
  requires              # dependent services
  excludes              # excluded services
  options               # per-environment config declarations
  crds                  # CRD generator function
  nixidy                # nixidy module (receives { config, charts, cluster, environment })
}
```

## Feature-to-Aspect Mapping

Features map 1:1 to den aspects.

### Platform Modules to Aspect Classes

| Feature attribute | Den aspect class | Notes                                    |
| ----------------- | ---------------- | ---------------------------------------- |
| `linux`           | `nixos`          | Direct mapping                           |
| `darwin`          | `darwin`         | Direct mapping                           |
| `home`            | `homeManager`    | Direct mapping                           |
| `homeLinux`       | `homeLinux`      | Custom forwarding class (see below)      |
| `homeDarwin`      | `homeDarwin`     | Custom forwarding class (see below)      |
| `os`              | `os`             | Uses den's built-in `os-class` provider  |
| `system`          | `os`             | Alias for `os`; deprecated during migration |

### Platform-Conditional Home Classes

`homeLinux` and `homeDarwin` are implemented as custom forwarding classes,
following the pattern established by den's `os-class` provider:

```nix
homeLinux-class = den.lib.perHost (
  { host }: { class, aspect-chain }: den._.forward {
    each = lib.optional (host.class == "nixos") true;
    fromClass = _: "homeLinux";
    intoClass = _: "homeManager";
    fromAspect = _: lib.head aspect-chain;
  }
);

homeDarwin-class = den.lib.perHost (
  { host }: { class, aspect-chain }: den._.forward {
    each = lib.optional (host.class == "darwin") true;
    fromClass = _: "homeDarwin";
    intoClass = _: "homeManager";
    fromAspect = _: lib.head aspect-chain;
  }
);
```

These are included as providers in `den.ctx.default.includes` or similar,
allowing aspects to declare `homeLinux` and `homeDarwin` as first-class classes
without conditionals.

### Composition Primitives

| Feature concept      | Den equivalent               | Notes                           |
| -------------------- | ---------------------------- | ------------------------------- |
| `requires`/`includes`| `includes`                   | Direct mapping                  |
| `provides`           | `provides`                   | Direct mapping                  |
| `settings`           | Schema options + `mkDefault` | Feature defaults via `mkDefault`|
| `collectsProviders`  | Custom forwarding classes    | See below                       |
| `contextProvides`    | Not directly supported       | See open questions              |

### Settings Layering

Feature settings become schema options on `den.schema.host` and `den.schema.user`.
Precedence is managed via the module system:

```
feature defaults (mkDefault) -> host.settings -> user.settings
```

Environment-level settings are not currently in use. When needed, an
environment aspect can set `mkDefault` values via `provides.host`.

### Collection Pattern (replaces `collectsProviders`)

Instead of a two-phase resolver that scans active features for matching providers,
den uses custom forwarding classes. Each aspect declares config in a custom class,
and the forwarding class collects and routes all contributions.

Example for impermanence/persist:

```nix
# Forwarding class definition (persist aspect)
# Wrapped in den.lib.perHost to bind host context, following gwenodai's pattern
persist-class = den.lib.perHost (
  { class, aspect-chain }: den._.forward {
    each = lib.singleton true;
    fromClass = _: "persist";
    intoClass = _: "nixos";
    intoPath = _: [ "preservation" "preserveAt" "/persist" ];
    fromAspect = _: lib.head aspect-chain;
    guard = { options, ... }: _:
      lib.mkIf (options ? preservation);
    adaptArgs = args: args // { osConfig = args.config; };
  }
);

# Any active aspect contributes by declaring the class
den.aspects.firefox = {
  persist = { ... }: {
    directories = [ ".mozilla" ];
  };
};
```

This pattern applies to: firewall rules, agenix secrets, impermanence/persist,
and any other cross-cutting concern that currently uses `collectsProviders`.

## Output Generation

### NixOS/Darwin Outputs

Handled by den's built-in `ctx.flake-system.into.flake-os`. The environment
context stage feeds resolved hosts into den's host pipeline. Den generates
`nixosConfigurations` and `darwinConfigurations` as standard flake outputs.

### Kubernetes/Nixidy Outputs

Custom output generation following the `flake-parts-modules` template pattern:

```nix
# Context stage: flake-cluster fans out into clusters
den.ctx.flake-cluster.into.cluster = _:
  map (cluster: { inherit cluster; }) (lib.attrValues den.clusters);

# Context stage: cluster fans out into k8s-services
den.ctx.cluster.into.k8s-service = { cluster }:
  map (service: { inherit cluster service; })
    (resolveEnabledServices cluster);

# Forward bridge for k8s-service aspects
den.ctx.flake-cluster-service.provides.flake-cluster-service = _: clusterServiceFwd;
clusterModule = den.lib.aspects.resolve "nixidy" (den.ctx.flake-cluster { });

# Wire into flake outputs
flake.nixidyConfigurations = clusterModule;
```

### Deployment Outputs

Colmena and deploy-rs wire into the `nixosConfigurations` that den produces.
No changes to deployment tooling needed.

## Groups / ACL

Groups remain a top-level option, not a den entity. They are consumed at two
points in the pipeline:

1. **`environment.into.host` -> `into.user` fan-out:** Three-level ACL resolution
   (groups -> environment.access -> host.system-access-groups) determines which
   users materialize on each host. This runs during the `into.user` transition.

2. **`cluster.into.k8s-service` evaluation:** Kanidm-scoped groups provide
   OAuth2 scope/claim maps consumed by k8s service aspects.

Resolution algorithm (unchanged from current):

```
groups                                 <- shared definitions (kanidm, unix, system scopes)
  |
environments.<env>.access              <- user -> [group] bindings per environment
  |
environments.<env>.system-access-groups <- env-wide baseline login gates
  + hosts.<host>.system-access-groups   <- host-specific login gates (merged)
  |
resolved user                          <- enable + systemGroups derived
```

## Migration Path

Current flake-parts option modules gradually replaced by den schemas and context
stages:

| Current module                      | Replaced by                              |
| ----------------------------------- | ---------------------------------------- |
| `flake-parts/hosts/options.nix`     | `den.schema.host` extensions             |
| `flake-parts/environments/options.nix` | `den.schema.environment`              |
| `flake-parts/users/options.nix`     | `den.schema.user` extensions             |
| `flake-parts/features/options.nix`  | `den.aspects` definitions                |
| `flake-parts/features/resolver.nix` | Den's include resolution + forwarding    |
| `flake-parts/kubernetes/*.nix`      | `den.schema.cluster` + `den.schema.k8s-service` |
| `flake-parts/hosts/utils.nix` (mkHost) | Den's `ctx.host` + output generation |
| `flake-parts/users/helpers.nix`     | ACL resolution in `into.user` transition |
| Feature `system`/`linux`/`darwin`/`home` modules | Aspect class declarations    |

## Implementation Approach

Hybrid (approach C): Define custom context stages (environment, cluster,
k8s-service) and schemas in this repository. Contribute upstream to den only
where extension mechanisms are insufficient. Currently no upstream changes are
anticipated — den's context system, forwarding classes, and schema extensibility
cover all identified requirements.

## Open Questions

- Exact integration point for colmena/deploy-rs node generation with den's
  output pipeline
- Whether `homeLinux-class`/`homeDarwin-class` providers should be contributed
  upstream to den as general-purpose batteries
- Optimal granularity for aspect splitting during migration (1:1 with current
  features vs. further decomposition)
- Migration path for `contextProvides` — features that inject computed values
  into the dispatch context have no direct den equivalent; each usage needs
  case-by-case analysis
- Migration path for `host.channel` (per-host nixpkgs channel selection) and
  how it integrates with den's `host.instantiate`
- Migration path for `host.baseline.home` (host-specific home-manager config
  applied to all users on that host)
- Migration path for `homeRequiresSystem` (guard preventing home module
  inclusion when system module cannot apply)

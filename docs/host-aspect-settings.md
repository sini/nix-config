# Typed per-aspect settings in Den

A how-to for giving shared aspects per-host knobs. If you build configurations
with [Den](https://github.com/sini/den) (or any dendritic / aspect-oriented Nix
setup), this guide shows how to let an aspect expose a few typed values — a disk
device id, a kernel optimization target, a BGP AS number — that each host fills
in, without forking the aspect.

It is written to be replicated in **your own** configuration, not just read as a
description of one repo. It has two parts:

- **Part 1 — the module-system pattern.** What ships today: aspects declare
  options, a generator in your host schema discovers them and assembles one
  strongly-typed `host.settings` tree, hosts set values, aspects read them back.
  This part includes the **generator recipe** — the ~80 lines you implement once
  in your host schema. Concrete examples are drawn from
  [`sini/nix-config`](https://github.com/sini/nix-config), used here purely as a
  reference implementation.

- **Part 2 — the first-class settings citizen (addendum).** The library-backed
  version shipping with den-hoag, built on
  [gen-aspects](https://github.com/sini/gen-aspects): explicit per-field merge
  strategies, a graph-based cascade, a policy layer, contract-checked injection,
  and per-field provenance. This is where the pattern is headed.

---

## The problem it solves

Aspects (the reusable units composed into a host — roles, hardware profiles,
disk layouts, services) are shared across many machines. Most of an aspect is
identical everywhere. But a few values are inherently per-host:

- a ZFS disk layout needs the **disk device id** — different on every box;
- a kernel aspect needs the **CPU optimization target** — `zen4` here, `server`
  there;
- a BGP aspect needs this node's **local AS number**.

The naive fixes are all bad: hard-code the value and the aspect stops being
reusable; add a bespoke top-level option per aspect and the host schema grows
without bound; read it from a global and you lose typing and locality.

The settings pattern gives each aspect a typed, namespaced slot that the host
fills in. Aspects declare their own option schema; the host schema discovers
those declarations automatically and assembles them into one strongly-typed
settings tree.

## The four moving parts

```
┌─ 1. Aspect DECLARES settings ──────────────────────────────────────────┐
│   den.aspects.core.system.linux-kernel = {                             │
│     settings = { optimization = lib.mkOption { ... }; };               │
│   };                                                                    │
└────────────────────────────────────────────────────────────────────────┘
                              │  (auto-discovered)
                              ▼
┌─ 2. Host schema GENERATES the typed namespace ─────────────────────────┐
│   your host schema walks den.aspects, mirrors the tree, and produces   │
│   a typed option at:                                                     │
│     host.settings.core.system.linux-kernel.optimization                 │
└────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─ 3. Host SETS values ──────────────────────────────────────────────────┐
│   den.hosts.x86_64-linux.cortex.settings = {                           │
│     core.system.linux-kernel.optimization = "zen4";                    │
│   };                                                                    │
└────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─ 4. Aspect CONSUMES values ────────────────────────────────────────────┐
│   nixos = { host, pkgs, ... }:                                         │
│     let cfg = host.settings.core.system.linux-kernel; in { ... };      │
└────────────────────────────────────────────────────────────────────────┘
```

The key property: **steps 1 and 4 live in the aspect, step 3 lives in the host,
and step 2 is automatic.** Adding a setting to an aspect never requires touching
the host schema. You implement the generator (step 2) exactly once.

---

# Part 1 — the module-system pattern

## A complete example end-to-end

The smallest aspect that exercises the whole pattern is a CachyOS kernel
selector. Here it is in full — declaration and consumption both live in one
file:

```nix
{ lib, ... }:
{
  den.aspects.core.system.linux-kernel = {
    # (1) DECLARE: two typed knobs, both with defaults.
    settings = {
      channel = lib.mkOption {
        type = lib.types.enum [ "lts" "latest" ];
        default = "latest";
        description = "CachyOS kernel release channel";
      };
      optimization = lib.mkOption {
        type = lib.types.enum [ "server" "zen4" "x86_64-v4" ];
        default = "server";
        description = "CachyOS kernel optimization target";
      };
    };

    # (4) CONSUME: the delivery module receives the resolved `host` entity and
    #     reads its own settings back out of host.settings.<this aspect's path>.
    nixos =
      { host, pkgs, ... }:
      let
        cfg = host.settings.core.system.linux-kernel;
        kernelName =
          if cfg.optimization == "server" then
            "linuxPackages-cachyos-server-lto"
          else
            "linuxPackages-cachyos-${cfg.channel}-lto-${cfg.optimization}";
      in
      {
        boot.kernelPackages = pkgs.cachyosKernels.${kernelName};
      };
  };
}
```

And a host fills in the one knob it cares about, letting `channel` fall back to
its default:

```nix
den.hosts.x86_64-linux.cortex.settings = {
  core.system.linux-kernel.optimization = "zen4";
};
```

That is the entire contract. The host never imports the aspect's option type,
never names a special argument, never wires anything up. It writes
`settings.core.system.linux-kernel.optimization` and the value lands inside the
aspect under the same path.

## Step 1 — Declaring settings on an aspect

Add a `settings` attribute to your aspect, as a sibling of `includes`, `nixos`,
and `homeManager`. The body is a set of plain `lib.mkOption` declarations:

```nix
den.aspects.disk.zfs-disk-single = {
  includes = [ den.aspects.disk.zfs-disk-single.root ];

  settings = {
    device_id = lib.mkOption {
      type = lib.types.str;
      description = "Disk device path for ZFS pool (e.g., /dev/disk/by-id/nvme-...)";
    };
  };

  nixos = { config, host, ... }: {
    # ... uses host.settings.disk.zfs-disk-single.device_id
  };
};
```

Two conventions:

- **`settings` holds option _declarations_, not config.** Put `mkOption`s here,
  not assignments. (If you genuinely need to ship default _config_ into the
  settings namespace, use the module-shaped form below.)
- **Omit `default` to make a setting required.** `device_id` above has no
  default, so any host that includes `zfs-disk-single` must set it or evaluation
  fails with a missing-required-option error. This is the type system enforcing
  "you must tell me which disk."

### Required vs. defaulted

| Form                                    | Behavior                                                |
| --------------------------------------- | ------------------------------------------------------- |
| `mkOption { type = ...; }` (no default) | Required. Host must set it; missing → eval error.       |
| `mkOption { type = ...; default = x; }` | Optional. Falls back to `x` when the host says nothing. |

Prefer defaults for anything with a sane fleet-wide value; reserve required
options for genuinely machine-specific facts (disk ids, AS numbers).

### The module-shaped form (advanced)

A `settings` block is normally a bare attrset of options. The generator also
accepts a **module-shaped** declaration with explicit `imports` / `config` /
`options` keys, so an aspect can both declare options _and_ seed default config
into the settings namespace:

```nix
settings = {
  options = {
    replicas = lib.mkOption { type = lib.types.int; default = 1; };
  };
  config = {
    # computed default beyond what `default =` can express
    replicas = lib.mkDefault 3;
  };
  imports = [ ./extra-settings-module.nix ];
};
```

The generator reshapes a bare attrset into this same shape automatically, so you
only reach for the explicit form when you need `config` or `imports`. Because
the settings tree is evaluated by the NixOS module system, normal priorities
apply — `lib.mkDefault` / `lib.mkForce` all work, and a value the host sets
plainly wins over an aspect's `mkDefault`.

## Step 2 — The generator (the part you implement once)

This is the half that lets others replicate the pattern: the bit of your **host
schema** that turns "aspects that happen to declare `settings`" into a single
strongly-typed `host.settings` option tree. You write it once; from then on
every aspect's settings appear automatically.

### Background: how a Den entity schema is shaped

If you are new to Den, this is the one piece of framework background you need
before the generator makes sense.

Den builds each entity kind — `host`, `environment`, `user`, `group` — from a
schema you declare under `den.schema.<kind>`. The key that matters here is
`den.schema.<kind>.imports`: **a list of plain NixOS-style modules whose
`options` become that entity's options.** Here is a complete, minimal entity
schema — the `group` entity, lightly trimmed — so you can see the bare shape:

```nix
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  den.schema.group.imports = [
    (_: {
      options = {
        gid = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "POSIX group ID";
        };
        # ... more options ...
      };
    })
  ];
}
```

That is the entire skeleton: a file that is itself a flake-parts/den module, and
inside it a `den.schema.<kind>.imports` list. Every entity in Den — including
`host` — is built exactly this way; the host schema is just a bigger version of
the above.

The file's **function arguments** are your building blocks:

- `lib` — nixpkgs `lib` (`mkOption`, `types`, `filterAttrs`, …).
- `inputs` — your flake inputs (e.g. to instantiate `gen-algebra` for
  validators).
- `den` — the **accumulated framework registry**, and the reason the generator
  can exist at all. `den.aspects` is the entire aspect tree; `den.classes` the
  registered output classes (`nixos`, `homeManager`, …); `den.quirks` any
  extensions. The generator reads `den.aspects` to discover settings and
  `den.classes` / `den.quirks` to know which keys are framework machinery rather
  than child aspects.

So the plan for the host is: compute a `settingsType` from `den.aspects` in the
file's `let` block, then attach it as one more option (`settings`) inside
`den.schema.host.imports`. The next two subsections show each half.

### Required first: reserve `settings` as a structural key

The generator below decides which keys to walk and which to skip via `skipKey`,
which consults `den.lib.aspects.fx.keyClassification.structuralKeysSet` (plus
`den.classes` / `den.quirks`). For this to work, **Den must classify `settings`
itself as framework machinery, not as an ordinary aspect key.** You declare that
once, in any module merged into the den config:

```nix
# e.g. modules/den/defaults.nix
den.reservedKeys = [ "settings" ];
```

This adds `settings` to `structuralKeysSet` — exactly the set `skipKey` checks.

**This step is not optional, and skipping it fails loudly.** Without it,
`skipKey "settings"` is `false`, so the tree walk descends _into_ your
`settings` block — into each `mkOption`, then into its `type` (a `lib.types.*`
value whose internal `functor.type` is self-referential) — and recurses forever:

```
nix-repl> den.hosts.x86_64-linux.<host>.settings
error: stack overflow; max-call-depth exceeded
       at .../host.nix: … hasSettingsDeep …
```

The recursion path makes the cause obvious — it is walking option/type
internals, which it must never touch:

```
<host>.settings.<aspect>.<key>.type.functor.type.functor.type.functor…
```

If you are porting this pattern to a non-Den framework, the rule generalizes:
**whatever key you use for settings must be in the set `skipKey` consults before
you wire up the generator.** Otherwise the generator mistakes your option
declarations for child aspects and walks straight into the type system.

### The generator

The contract `settingsType` implements:

> For every node in the aspect tree that has a `.settings` attribute, emit a
> typed submodule option at the **same path** under `host.settings`. A node may
> be both an aspect-with-settings _and_ a parent of settings-bearing children;
> merge both. Ignore keys that are framework machinery rather than child
> aspects.

Here it is in full, annotated. It is a single value computed in the host
schema's `let` block (so `den`, `lib`, and `types` are in scope). In
`sini/nix-config` this lives in `modules/den/schema/host.nix`.

```nix
settingsType =
  let
    # Keys that are NOT child aspects: structural keys (includes, nixos, …),
    # plus your framework's registered class names and quirk/extension keys.
    # Adapt these three sources to your own framework.
    inherit (den.lib.aspects.fx.keyClassification) structuralKeysSet;
    classKeys = den.classes or { };
    quirkKeys = den.quirks or { };
    skipKey = k: structuralKeysSet ? ${k} || classKeys ? ${k} || quirkKeys ? ${k};

    # A settings block may be a plain options attrset ({ foo = mkOption {...}; })
    # OR module-shaped ({ imports; config; options; }). Normalize to the latter.
    reshapeSettings =
      raw:
      let
        # Bind to DISTINCT names on purpose — see the statix gotcha below.
        imports' = raw.imports or [ ];
        config' = raw.config or { };
      in
      {
        imports = imports';
        config = config';
        options = removeAttrs raw [ "imports" "config" ];
      };

    # True if this node, or anything beneath it, declares settings.
    hasSettingsDeep =
      node:
      builtins.isAttrs node
      && (
        (node ? settings)
        || lib.any (k: !(skipKey k) && hasSettingsDeep (node.${k} or null)) (builtins.attrNames node)
      );

    # Build the submodule for one aspect-tree node, mirroring the tree.
    # Merge the node's OWN settings options with recursion into its
    # settings-bearing children.
    nodeModule =
      node:
      let
        ownSettings =
          if node ? settings then
            reshapeSettings node.settings
          else
            { imports = [ ]; config = { }; options = { }; };

        settingChildren = lib.filterAttrs (
          k: v: !(skipKey k) && builtins.isAttrs v && hasSettingsDeep v
        ) node;

        childOptions = lib.mapAttrs (
          name: child:
          mkOption {
            type = types.submodule (nodeModule child);
            default = { };
            description = "Settings under ${name}";
          }
        ) settingChildren;

        # Distinct names again — keep statix from dropping the `or` default.
        ownImports = ownSettings.imports or [ ];
        ownConfig = ownSettings.config or { };
      in
      {
        imports = ownImports;
        config = ownConfig;
        options = (ownSettings.options or { }) // childOptions;
      };
  in
  types.submodule (nodeModule (den.aspects or { }));
```

### Wiring it together

Now put both halves in one file. The generator lives in the `let`; the
`settings` option is attached inside `den.schema.host.imports` alongside the
host's other options. This is the whole host schema in skeleton form — the parts
that matter are highlighted, everything else (`channel`, `networking`, …) is a
normal `mkOption` you add as needed:

```nix
{ lib, inputs, den, self, ... }:        # ← note `den` in the arguments
let
  inherit (lib) mkOption types;

  # ... other helpers: interfaceType, channel definitions, etc. ...

  settingsType =
    let
      # skipKey / reshapeSettings / hasSettingsDeep / nodeModule
      # (the generator from the previous subsection)
      # ...
    in
    types.submodule (nodeModule (den.aspects or { }));   # ← reads the aspect tree
in
{
  den.schema.host.isEntity = true;

  den.schema.host.imports = [
    (
      { config, ... }:
      {
        options = {
          channel = mkOption { /* ... */ };
          environment = mkOption { /* ... */ };
          # ... the rest of the host's options ...

          # The generated, auto-discovered settings namespace:
          settings =
            mkOption {
              type = settingsType;
              default = { };
              description = "Per-aspect typed settings";
            }
            # Exclude settings from entity identity hashing (see Gotchas).
            // {
              identity = false;
            };
        };

        # config = { ... };   # computed defaults for other options, if any
      }
    )
  ];
}
```

Three things to notice on a first read:

- The whole file is **one module function with `den` in its arguments** — that
  is how `settingsType` can see `den.aspects`. If your framework hands you the
  registry under a different name, use that instead.
- `settings` is just **one option among many** on the host. Nothing else in the
  schema needs to know it exists; aspects and hosts wire themselves up through
  it automatically.
- The `// { identity = false; }` marker is `nix-config`-specific (its entity
  identity hashing — see Gotchas). Omit it if your framework has no such
  concept.

That is the entire host-side investment: one option, backed by one ~80-line
`let` binding, written once. Every aspect that later declares `settings` shows
up under `host.settings` with no further schema edits.

How the three helpers earn their keep:

- **`skipKey`** is the only framework-specific part. It must return `true` for
  every key that is _not_ a child aspect — structural keys (`includes`, `nixos`,
  `homeManager`, …), your class names, and any extension/quirk keys. Get this
  wrong and the generator will try to mint `host.settings.<aspect>.nixos`. Point
  it at whatever your framework uses to classify keys.
- **`hasSettingsDeep`** prunes the recursion so empty branches don't generate
  empty submodules — only paths that actually lead to a `settings` block become
  options.
- **`nodeModule`** is the recursion proper. The crucial subtlety is that a node
  can carry **both** its own `settings` **and** settings-bearing children. It
  merges `ownSettings.options` with the generated `childOptions`, so a parent
  aspect's own knobs and its children's knobs coexist under one path.

Because `settingsType` is a `types.submodule`, the resulting `host.settings` is
a normal NixOS option tree: typed, validated, and subject to module-system
priority (`mkDefault`/`mkForce`). You get type errors at the exact path for
free.

## Step 3 — Setting values on a host

In a host definition, write a `settings` attribute. Address values by the
aspect's path. Nested and dotted attribute syntax are interchangeable in Nix:

```nix
den.hosts.x86_64-linux.cortex = {
  channel = "nixpkgs-master";
  environment = "dev";
  # ...
  settings = {
    disk.zfs-disk-single.device_id =
      "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_…";

    core.system.linux-kernel.optimization = "zen4";

    core.impermanence = {
      wipeRootOnBoot = true;
      wipeHomeOnBoot = false;
    };
  };
};
```

Every value is typed, so a typo in the path or a wrong-typed value is a
build-time error pointing at the exact option, not a silently ignored attribute.
A host happy with every default writes no `settings` at all.

## Step 4 — Consuming settings inside the aspect

The aspect's delivery modules (`nixos`, `homeManager`) are functions that
receive the fully-resolved `host` entity as a module argument. Read your own
settings out of `host.settings.<your.aspect.path>`:

```nix
nixos =
  { config, host, ... }:
  let
    disk-device = host.settings.disk.zfs-disk-single.device_id;
  in
  {
    disko.devices.disk.disk0.device = disk-device;
    # ...
  };
```

Conventions that keep consumers readable:

- **Bind a `cfg` alias** to your settings subtree
  (`cfg = host.settings.core.system.linux-kernel;`), then use `cfg.optimization`
  — exactly the `cfg = config.services.foo` idiom from upstream NixOS modules.
- **Read by the canonical path.** Always read the same path you declared. An
  aspect _can_ read another aspect's settings (it is all one `host.settings`
  tree), but do that sparingly — it couples the two aspects.

`host` is the resolved host entity, so the same argument also yields
`host.system`, `host.environment`, `host.networking`, etc. Settings are just one
branch of it.

## Layering and precedence

Two layers of precedence compose.

**Within a host**, `host.settings` is a NixOS submodule, so module-system
priority applies. Weakest to strongest:

1. the `default =` on the aspect's `mkOption`;
2. any `config` an aspect seeds via the module-shaped settings form (typically
   `lib.mkDefault`);
3. the plain value the host writes in its `settings` block;
4. `lib.mkForce` anywhere overrides the lot.

**Across the fleet**, a settings _cascade_ can layer
`root → environment → host`. In `sini/nix-config` this is a scope graph
(`modules/den/scope-engine/settings.nix`) that resolves, per node, `local`
shadowing `imported` shadowing `parent`, with environments exposing a loose
`settings` option for fleet- or environment-wide defaults:

```
root  <  environment  <  host        (later wins)
```

In day-to-day aspect work you read the strongly-typed `host.settings`; the
cascade is the layer that lets an environment set a default for every host it
owns without each host repeating it. Part 2 generalizes this cascade into a
first-class, provenance-tracked construct.

## Gotchas and rules

- **`stack overflow; max-call-depth exceeded` in `hasSettingsDeep` → you forgot
  `den.reservedKeys = [ "settings" ];`.** This is the single most common
  first-time failure. If `settings` isn't reserved, `skipKey` lets the tree walk
  descend into your option declarations' `type` values, which are
  self-referential, and the stack blows. See
  [Required first: reserve `settings`](#required-first-reserve-settings-as-a-structural-key).

- **Declarations are options; config is config.** A bare `settings` attrset must
  contain only `mkOption`s. If you catch yourself writing `foo = "bar";` (an
  assignment) directly in `settings`, you want either
  `mkOption { default = "bar"; }` (to expose it as a knob) or the module-shaped
  form with a `config` block (to seed it).

- **The `or`-default / statix W04 trap.** The generator deliberately binds
  `imports' = raw.imports or [ ]` and `config' = raw.config or { }` to
  _distinct_ local names. Do not "simplify" these to `inherit (raw) imports;` —
  statix's W04 rule rewrites `imports = raw.imports or [ ]` into
  `inherit (raw) imports`, which **drops the `or` default** and throws the
  moment a plain-attrset settings block (the common case) has no `imports` key.
  Keep the distinct bindings, and keep the explanatory comments next to them.
  (If you run statix via a formatter, this rewrite can sneak in on save — pin or
  disable W04 for that file.)

- **Exclude settings from entity identity.** If your framework hashes entities
  by their option values, mark `settings` (like `networking`, `facts`,
  `exporters`) as identity-excluded so two hosts that differ only in settings
  stay distinct-by-name and settings don't perturb identity hashing. In
  `nix-config` this is `// { identity = false; }` on the option.

- **Path must match exactly.** `host.settings.<path>` consumed in an aspect must
  be the same path the aspect declared `settings` under. The generator keys off
  the aspect's position in the tree; there is no aliasing.

- **A missing required setting fails loudly.** Including an aspect without
  setting its required options is a hard error. That is the design — it makes
  "you forgot to say which disk" un-shippable rather than a runtime surprise.

## Checklist for adding a new setting

1. In the aspect, add an `mkOption` to its `settings` block (create the block if
   absent). Give it a `default` unless it is genuinely per-host required.
2. In the aspect's `nixos` / `homeManager` function, take `host` as an arg and
   read `host.settings.<aspect.path>.<key>` (alias it to `cfg`).
3. On each host that needs a non-default value, set
   `settings.<aspect.path>.<key>` in its host block.
4. Build the affected host to confirm the type resolves and required values are
   present.

---

# Part 2 — addendum: the first-class settings citizen

Part 1 hand-rolls the mechanism out of the NixOS module system: settings are
`mkOption`s, the cascade is module priority plus a side scope graph, and an
aspect reads `host.settings` directly. It works and it is what ships today.

The pattern shipping with **den-hoag** promotes settings to a first-class,
library-backed construct via [gen-aspects](https://github.com/sini/gen-aspects).
The reference is the gen-aspects demo
(`examples/demo/modules/{composition,settings,injection}.nix`). The differences
are deliberate and worth understanding before you build on the Part 1 version.

## What changes

### Settings schemas carry merge strategy, not just type

A settings field is a small schema leaf with a `default` and an optional `merge`
strategy — `replace` (default), `append`, or `recursive`:

```nix
# aspects/web.nix — services.nginx
settings = {
  performance.workers = { default = 4; };
  security.allowed-origins = { default = [ ]; merge = "append"; };
  upstream.servers       = { default = [ ]; merge = "append"; };
  locations              = { default = { }; merge = "recursive"; };
};
```

`merge` makes the cascade's behavior explicit per field rather than implicit in
NixOS option types: `append` accumulates lists across layers, `recursive`
deep-merges attrsets per subkey, `replace` is last-wins. This is the single
biggest ergonomic gain over Part 1, where merge semantics are whatever the
option type happens to do.

The schema is registered as a typed collection on the aspect kind, so `flatten`
and the cascade can introspect it (this is the gen-schema replacement for Den's
old `reservedKeys` string-exclusion — declare `settings` via `aspectModules`):

```nix
aspectSchema = genAspects.mkAspectSchema {
  classes = { nixos = { }; };
  collections = { settings = { default = { }; }; tags = { default = [ ]; }; };
  aspectModules = [
    { options.settings = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw; default = { };
    }; }
  ];
};
```

### Overrides are keyed by scope node, decoupled from the entity

Instead of writing values inline on each host, overrides live in one
`scopeSettings` map keyed by scope node id (`env:<name>` / `host:<name>`):

```nix
config.scopeSettings = {
  "env:prod"        = { nginx.performance.workers = 16; app.logging.level = "warn"; };
  "host:prod-web-1" = { nginx.performance.workers = 32;
                        nginx.upstream.servers = [ "app-1:3000" "app-2:3000" ]; };
};
```

This separates "what an entity is" from "what settings it carries," and makes
the environment layer a peer of the host layer rather than a side channel.

### The cascade is an explicit, traced fold

`composition.nix` runs a real pipeline rather than relying on module-merge
order:

1. **Extract** every aspect's settings schema (`flatten` + `flattenSchema`),
   producing flat `defaults` and `strategies` maps namespaced by aspect leaf.
2. **Build a scope graph** (gen-scope): env nodes as roots, host nodes with
   parent-edges to their env.
3. **Collect layers** with a gen-scope _neron_ traverse in `D > I > P` order
   (most-specific first: host, then imports, then parent env), carrying a
   parallel list of contributing node ids so layers can be labeled.
4. **Fold** with `gen-algebra`'s `record.foldLayersTraced`, applying each
   field's strategy and recording, per field, **which layer won**.

```
aspect default:  nginx.performance.workers = 4
env:prod:        nginx.performance.workers = 16
host:prod-web-1: nginx.performance.workers = 32   ← wins (replace, last)

aspect default:  nginx.upstream.servers = []
host:prod-web-1: nginx.upstream.servers = ["app-1:3000","app-2:3000"]   (append)
```

### Policy is a first-class final layer

A `gen-derive` fixpoint dispatches policy rules (e.g. "production hosts get
hardening", "db hosts get a backup schedule"). Rules emit typed `configure`
actions carrying `{ aspect; settings; }`, which are folded in as the **last**
cascade layer — so policy beats both env and host:

```nix
layers     = entityLayers ++ [ policyLayer ];   # policy appended LAST → wins
layerNames = entityNames  ++ [ "policy" ];
```

### Injection replaces `host.settings` reads

In Part 1 an aspect reaches into `host.settings.<full.path>`. Here the aspect's
class content is **parametric** over a `settings` argument, namespaced by the
aspect's leaf name:

```nix
nixos = { settings, host, lib, ... }: {
  services.nginx.config = ''
    worker_processes ${toString settings.nginx.performance.workers};
  '';
};
```

`injection.nix` closes the loop. For each `(host, aspect)` pair,
`injectAspectSettings` binds the cascade's `composedSettings.<host>.<leaf>`
(plus `host`) into the class content via `genBind.wrap`, with a **contract**
asserting `settings` is a set and a **provenance** stamp — producing a ready-to-
`evalModules` module:

```nix
injectAspectSettings = { host, aspectLeaf, classContent }:
  (genBind.wrap {
    module   = classContent;
    bindings = {
      settings = { ${aspectLeaf} = composedSettings.${host}.${aspectLeaf} or { }; };
      host     = { name = host; } // (config.fleet.hosts.${host} or { });
    };
    contracts.settings  = genBind.contract.isType "set";
    provenance.settings = { source = "scope-settings"; scope = "host:${host}"; };
  }).module;
```

Resolved settings are injected **before** `evalModules`, so a parametric aspect
can read values that do not exist until the cascade has run — without the aspect
ever importing the cascade or knowing about scope ids.

### Provenance is queryable

`foldLayersTraced` records the winning layer per field (and per subkey on
`recursive` fields), turning "why is this value what it is?" into a value you
can assert on:

```
loggingLevelProdWeb1Winner   # "policy"  — policy beat env's "warn"
workersProdWeb1Winner        # "host"    — negative control; policy left it alone
dbBackupSubkeyProvenance     # { schedule = "policy"; method = "host"; … }
```

## Part 1 vs. Part 2 at a glance

| Concern              | Part 1 (module system)                    | Part 2 (gen-aspects, den-hoag)                         |
| -------------------- | ----------------------------------------- | ------------------------------------------------------ |
| Declaration          | `mkOption` (full NixOS types)             | schema leaf `{ default; merge?; }`                     |
| Merge semantics      | implicit in option type + module priority | explicit per field: `replace` / `append` / `recursive` |
| Override location    | inline on the host entity                 | `scopeSettings` keyed by scope node id                 |
| Cascade              | side scope graph; module priority in-host | gen-scope graph + neron traverse + traced fold         |
| Policy layer         | none (or ad-hoc)                          | gen-derive fixpoint `configure` actions, folded last   |
| Aspect consumes      | `host.settings.<full.path>`               | parametric `settings.<leaf>`, injected via gen-bind    |
| Injection guarantees | module-system typing                      | contracts + provenance, bound before `evalModules`     |
| Provenance           | not tracked                               | per-field (and per-subkey) winning-layer trace         |

## When to use which

- **Reach for Part 1** when you want the smallest possible mechanism, full NixOS
  option typing/validation, and you are comfortable with module-merge semantics.
  It is a great default and the generator is ~80 lines.
- **Reach for Part 2** when you need explicit per-field merge strategies, a
  layered cascade with a policy tier, settings injected into parametric modules
  with contracts, or auditable provenance ("which layer set this, and why?").
  This is the direction den-hoag formalizes, so building on it aligns with where
  the framework is going.

The two are not exclusive: a config can keep `mkOption`-typed `host.settings`
for machine facts while adopting the gen-aspects cascade for fleet-wide feature
settings. The migration path is to move a setting's _declaration_ from an
`mkOption` to a schema leaf and its _consumption_ from `host.settings.<path>` to
an injected `settings.<leaf>` arg.

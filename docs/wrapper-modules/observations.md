# Wrapper Modules: Observations & Adapter Strategy

> See also: [gitkraken-case-study.md](./gitkraken-case-study.md) — detailed
> walkthrough of wrapping a real HM-dependent feature

## 1. The Two Patterns

### Our feature system (monolithic, context-rich)

Features are evaluated **inside** a full NixOS/home-manager evaluation. Every
home module receives rich context injected via `_module.args` and
`extraSpecialArgs`:

| Argument      | Source                                      | Example usage                              |
| ------------- | ------------------------------------------- | ------------------------------------------ |
| `user`        | Resolved per-user (canonical + env + host)  | `user.identity.email`, `user.settings.git` |
| `settings`    | System-level feature settings               | `settings.tailscale.openFirewall`          |
| `environment` | Environment config                          | `environment.email.domain`                 |
| `host`        | Host config with helpers                    | `host.hasFeature "xserver"`, `host.isDarwin` |
| `inputs`      | Flake inputs                                | `inputs.firefox-addons`, `inputs.nvf`      |
| `users`       | All resolved users                          | Group membership, multi-user coordination  |

This is the strength of the monolithic approach — features can discover each
other, share identity, respond to host topology. But it means a configured
firefox is **locked inside** a NixOS evaluation; you cannot `nix run` it.

### nix-wrapper-modules (portable, isolated)

Each wrapper is evaluated via a standalone `lib.evalModules` call. The output is
a plain derivation. Wrappers receive only `pkgs` and whatever you pass to
`.wrap {}`. They know nothing about hosts, users, environments, or other
features.

The tradeoff: portability at the cost of context.

## 2. Feature Classification

Not all features are equal candidates for wrapping. They fall into tiers based
on what context they consume:

### Tier 1 — Pure home modules (wrap directly)

These features define a `.home` module that only uses `pkgs`, `lib`, `config`
(the home-manager config), and maybe `inputs` for extra packages. They have no
dependency on `user`, `host`, `environment`, or `settings`.

Examples:
- **alacritty** — static `programs.alacritty.settings`, no external context
- **starship** — static `programs.starship.settings`
- **kitty** — static terminal settings
- **zoxide** — `programs.zoxide.enable = true`
- **yazi** — file manager config with plugins from `inputs`
- **obs-studio** — plugins list, no identity/host deps

These could be converted to wrapper modules almost mechanically.

### Tier 2 — Identity-dependent (wrap with identity injection)

These consume `user.identity` or `user.settings` but nothing deeper.

Examples:
- **git** — needs `user.identity.email`, `user.identity.displayName`,
  `user.identity.gpgKey`, `user.settings.git.extraIdentities`,
  `environment.email.domain`
- **jujutsu** — needs `user.identity.gpgKey` for commit signing
- **gpg** — needs `host.hasFeature "xserver"` for pinentry selection,
  `host.isDarwin` for platform choice

These need an identity/context object passed in, but it is a bounded, known
shape.

### Tier 3 — System-entangled (keep as NixOS modules)

These have `.linux`/`.system` modules that configure system-level resources, or
their `.home` module tightly couples with `osConfig`.

Examples:
- **steam** — system-level `programs.steam`, nix cache config, GPU feature
  detection via `host.hasFeature`
- **vr-amd** — kernel patches, system modules, flatpak + HM coordination
- **spicetify** — system module adds overlays, home module consumes them
- **hyprland** — requires xdg-portal, uwsm system services

These should stay as NixOS feature modules. Wrapping them would lose the
system-level half.

### Tier 4 — System-only (not applicable)

Features with no `.home` module at all: coolercontrol, tailscale system config,
networking, etc. These are purely system-level and wrapping doesn't apply.

## 3. What We Want From an Adapter

Goals:
1. **Keep the existing feature system unchanged** — features remain the
   authoritative source of truth for NixOS/HM configuration
2. **Automatically expose eligible features** as `packages.<system>.<name>`
   outputs for `nix run`
3. **Preserve the multi-layer settings resolution** — a wrapped package should
   reflect the same resolved settings a user would get on their host
4. **Allow standalone use** — `nix run .#alacritty` works without any host
   context for Tier 1 features
5. **Allow contextualized use** — `nix run .#git` works with identity injected
   for Tier 2 features

Non-goals:
- Replacing the NixOS/HM module path — the monolithic evaluation stays for
  system deployment
- Wrapping Tier 3/4 features — these are inherently system-coupled

## 4. Adapter Architecture

### Core idea: feature metadata annotation + home module extraction

```
features.<name> = {
  # existing fields...
  home = { ... };
  user-settings = { ... };

  # NEW: wrapper adapter metadata
  wrapper = {
    enable = true;                    # opt-in per feature
    package = pkgs.alacritty;        # base package to wrap
    tier = "pure" | "identity";      # determines what context is injected
    extraWrapperModules = [ ];       # additional wrapper-module config
  };
};
```

### The conversion function

A new helper, `mkWrappedPackage`, would:

1. **Extract the `.home` module** from the feature definition
2. **Evaluate it** in a minimal context (no full NixOS eval):
   - For Tier 1: just `pkgs` + `inputs`
   - For Tier 2: `pkgs` + `inputs` + a user context object
3. **Read the evaluated home-manager config** to extract:
   - The program's settings/config (e.g., `programs.alacritty.settings`)
   - Extra packages (e.g., firefox extensions)
   - Generated config files (e.g., git includes)
4. **Feed those into a wrapper-module** that produces the derivation

### The problem with direct home module reuse

Our `.home` modules are **home-manager deferred modules**. They expect the full
HM module system (`programs.X.enable`, `home.persistence`, `xdg.mimeApps`,
etc.). You cannot just evaluate them in a plain `lib.evalModules` — they need HM
option declarations.

This means the adapter has two possible strategies:

#### Strategy A: Dual definition (recommended for now)

Features that want wrapping define **both**:
- `.home` — the HM module (for NixOS deployment, as today)
- `.wrapper` — a wrapper-module definition (for `nix run`)

The wrapper definition can reference shared config extracted to a let-binding:

```nix
# modules/apps/productivity/alacritty.nix
let
  alacrittySettings = {
    general.live_config_reload = true;
    window = {
      decorations = "full";
      dynamic_title = true;
      title = "Terminal";
    };
    bell = {
      color = "#000000";
      duration = 200;
    };
  };
in
{
  features.alacritty = {
    # Existing HM module (unchanged)
    home = {
      programs.alacritty = {
        enable = true;
        settings = alacrittySettings;
      };
    };

    # NEW: wrapper module for nix run
    wrapper = {
      enable = true;
      package = "alacritty";           # resolved against pkgs
      settings = alacrittySettings;    # reuse the same config
    };
  };
}
```

Pros:
- No fragile HM evaluation gymnastics
- Shared config is a plain attrset — easy to factor out
- Wrapper can diverge from HM config where needed (e.g., skip persistence)
- Incremental adoption — only annotate features you want to wrap

Cons:
- Some duplication between `.home` and `.wrapper` (mitigated by shared lets)
- Two things to maintain per feature

#### Strategy B: HM module evaluation adapter (future, higher effort)

Build a shim that evaluates an HM module in a stripped-down HM context, then
extracts the relevant config. This would allow `.home` to be the single source
of truth.

Rough shape:
```nix
mkWrappedFromHome = { featureName, homeModule, pkgs, context ? {} }:
  let
    # Evaluate the home module in a minimal HM context
    hmEval = lib.evalModules {
      modules = [
        home-manager-option-declarations  # just the option types
        homeModule
        { _module.args = { inherit pkgs; } // context; }
      ];
    };
    # Extract program config
    programConfig = hmEval.config.programs.${featureName} or {};
  in
  wrappers.${featureName}.wrap {
    inherit pkgs;
    settings = programConfig.settings or {};
  };
```

This is more elegant but:
- Requires importing HM option declarations without the full HM evaluation
- Some HM modules have side effects (persistence, mimeApps) that don't map to
  wrappers
- `osConfig` references would fail
- Feature modules that use `config` (the HM config, e.g. `config.home.username`)
  need stubs

This could be pursued later as an optimization once the dual-definition pattern
proves which features are worth wrapping.

## 5. Integration Points

### Flake output generation

A new flake-parts module would iterate `config.features`, find those with
`wrapper.enable = true`, and populate `perSystem.packages`:

```nix
# modules/flake-parts/features/wrappers.nix
perSystem = { pkgs, ... }: {
  packages = lib.mapAttrs' (name: feature:
    lib.nameValuePair name (mkWrappedPackage {
      inherit pkgs name;
      inherit (feature) wrapper;
    })
  ) (lib.filterAttrs (_: f: f.wrapper.enable or false) config.features);
};
```

### User-contextualized packages

For Tier 2 features, we could generate per-user packages:

```
nix run .#alacritty          # Tier 1: no context needed
nix run .#git                # Tier 2: uses default identity
nix run .#git-sini           # Tier 2: uses sini's resolved identity
```

The per-user variants would resolve identity from `config.users.<name>` at flake
evaluation time.

### Settings passthrough

For features with `user-settings`, the wrapper could accept settings the same
way the HM path does:

```nix
# In the flake-parts wrapper module:
mkWrappedPackage {
  inherit pkgs;
  name = "git";
  wrapper = feature.wrapper;
  userSettings = resolveFeatureSettings {
    settingsKey = "user-settings";
    activeFeatureNames = [ "git" ];
    featuresConfig = config.features;
    layers = [
      # Use canonical user settings as defaults
      ({ lib, ... }: {
        config.git = lib.mapAttrs (_: lib.mkDefault) (user.system.settings.git or {});
      })
    ];
  };
};
```

## 6. Candidate Features for Initial Wrapping

Based on the tier classification, these are the best candidates to start with:

### Immediate (Tier 1 — zero context needed)

| Feature    | Complexity | Notes                              |
| ---------- | ---------- | ---------------------------------- |
| alacritty  | trivial    | Static settings only               |
| kitty      | trivial    | Static settings only               |
| starship   | low        | Large settings block, no deps      |
| zoxide     | trivial    | Just `enable = true`               |
| bat        | trivial    | Theming config                     |
| eza        | trivial    | Alias config                       |
| yazi       | low        | Plugins from inputs                |
| obs-studio | low        | Plugin list from pkgs              |

### Next (Tier 2 — needs identity/context injection)

| Feature  | Context needed                          | Notes                               |
| -------- | --------------------------------------- | ----------------------------------- |
| git      | `user.identity`, `user.settings.git`    | Most complex; conditional includes  |
| jujutsu  | `user.identity.gpgKey`                  | Signing config                      |
| gpg      | `host.hasFeature`, `host.isDarwin`      | Pinentry selection per platform     |
| firefox  | `inputs` (addons, betterfox, shimmer)   | Borderline Tier 1; inputs are heavy |

## 7. Open Questions

1. **Should wrapper modules be a new field on `features` or a parallel
   registry?** Adding `.wrapper` to the feature submodule is clean but couples
   the two systems. A parallel `wrappers.<name>` attrset that references
   features keeps them decoupled.

2. **How to handle `requires` for wrappers?** Git requires delta, gh, jujutsu,
   lazygit. For a wrapped git package, should those be bundled into the wrapper's
   PATH, or left as separate wrapped packages? Wrapper-modules supports
   `extraPackages` for this.

3. **Stylix/theming integration?** Many of our home modules benefit from stylix
   theme injection. Wrapper modules would need a theming bridge or accept theme
   settings explicitly.

4. **Home-manager persistence?** Wrappers don't have `home.persistence`. Features
   like firefox that rely on persistence directories would only get wrapping for
   the binary config, not the state management. This is acceptable — persistence
   is a deployment concern, not a package concern.

5. **nix-wrapper-modules as a flake input?** Do we vendor it, or add it as an
   input like we do with nvf, firefox-addons, etc.?

## 8. Recommended Next Steps

1. **Add `nix-wrapper-modules` as a flake input**
2. **Implement `mkWrappedPackage` helper** in `modules/flake-parts/features/`
   using Strategy A (dual definition)
3. **Pilot with alacritty and starship** — simplest possible features, validate
   the `nix run` flow
4. **Extend to kitty, bat, eza, zoxide** — build confidence in the pattern
5. **Tackle git** — first Tier 2 feature, validates identity injection
6. **Evaluate Strategy B feasibility** — can we extract HM config automatically
   for features that don't use system context?

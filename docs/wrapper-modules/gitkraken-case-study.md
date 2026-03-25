# Case Study: Wrapping GitKraken

Goal: `nix run .#sini.gitkraken` launches GitKraken with sini's identity, GPG
signing, catppuccin theme, and all settings baked in — without a NixOS or
home-manager evaluation.

## What the feature does today

```nix
# modules/apps/dev/git/gitkraken.nix
features.gitkraken.home = { inputs, pkgs, user, ... }: {
  imports = [ inputs.nixkraken.homeManagerModules.nixkraken ];

  programs.nixkraken = {
    enable = true;
    acceptEULA = true;
    # ... graph, ui, notifications settings ...
    user = {
      inherit (user.identity) email;
      name = user.identity.displayName;
    };
    gpg = {
      package = pkgs.gnupg;
      signCommits = user.identity.gpgKey or null != null;
      signTags = user.identity.gpgKey or null != null;
      signingKey = user.identity.gpgKey or null;
    };
  };

  home.persistence."/persist".directories = [
    ".gitkraken/" ".gk/" ".config/GitKraken/"
  ];
};
```

This is a Tier 2 feature: it needs `user.identity` and `inputs.nixkraken`, plus
our custom `pkgs.local.catppuccin-gitkraken` package.

## Why wrapping is hard

There are three distinct obstacles, each at a different level.

### Obstacle 1: The nixkraken module is a home-manager module

The `inputs.nixkraken.homeManagerModules.nixkraken` module declares options
under `programs.nixkraken` and implements them using HM-specific mechanisms:

- **`home.packages`** — installs the gitkraken binary, git, gpg, editor,
  terminal packages
- **`home.activation`** — runs `gk-configure -c '<JSON>'` and `gk-theme -i`
  after `writeBoundary` to write config to `~/.gitkraken/`
- **Reads from `config.programs.git`** — user email/name and GPG signing
  defaults fall through to `programs.git.userEmail`, `programs.git.signing.key`,
  etc.

A wrapper-module uses `lib.evalModules` in isolation. It knows nothing about
`home.packages`, `home.activation`, `programs.git`, or any other HM option. If
you import the nixkraken HM module into a wrapper evaluation, it will fail
immediately — the option declarations it depends on don't exist.

**This is the fundamental impedance mismatch**: HM modules declare options and
produce config in the HM option namespace. Wrapper modules produce a derivation.
The two evaluation contexts are incompatible.

### Obstacle 2: Config is applied at activation time, not build time

nixkraken doesn't generate config files in the Nix store. It runs `gk-configure`
as a **home-manager activation script** — an imperative step that executes after
the store derivation is built, writing JSON to `~/.gitkraken/` at activation
time.

A wrapped package must embed config at **build time** (in the derivation). The
activation-time approach means there's no store-path config file to point the
binary at. We'd need to:

1. Generate the same JSON that `gk-configure` would produce
2. Either inject it into the wrapper (env var, XDG override, or pre-populated
   config dir) or run `gk-configure` as part of the wrapper's startup

### Obstacle 3: Identity injection

The module reads `user.identity.email`, `user.identity.displayName`, and
`user.identity.gpgKey` from our flake's user resolution system. In a wrapper
context, there's no `user` arg — we need to resolve and inject it ourselves.

This is the simplest obstacle. We have `config.users.sini` available at flake
evaluation time and can thread it through.

## Strategy: Build the config JSON ourselves

The nixkraken HM module's actual output is straightforward: it accumulates all
options into a JSON object and passes it to `gk-configure`. We can reproduce
that JSON without evaluating the HM module at all.

### Step 1: Understand what nixkraken produces

The module builds a JSON config from `_submoduleSettings` — each option
submodule (graph, git, gpg, ssh, tools, ui, user, notifications) contributes a
portion. The final JSON looks roughly like:

```json
{
  "acceptedEULA": true,
  "showTutorial": false,
  "logLevel": "standard",
  "notifications": { "feature": false, "help": false, "marketing": false },
  "graph": { "compact": true, "showAuthor": true, ... },
  "gpg": { "signCommits": true, "signingKey": "0xABC..." },
  "user": { "email": "sini@...", "name": "..." },
  "tools": { "terminal": "/nix/store/.../bin/alacritty" },
  "ui": { "theme": "catppuccin-mocha.jsonc", ... }
}
```

### Step 2: Build a wrapper module that produces this

Instead of importing the HM module, we build a wrapper-module that:

1. Takes the gitkraken package as the base
2. Generates the config JSON at build time
3. Creates a wrapper script that:
   a. Ensures `~/.gitkraken/` exists
   b. Runs `gk-configure` with our JSON (or writes it directly)
   c. Installs themes
   d. Launches gitkraken

```nix
# Pseudocode for the wrapper module
{ pkgs, wlib, identity, ... }:
let
  gitkrakenPkg = inputs.nixkraken.packages.${pkgs.system}.gitkraken;
  gkConfigure = inputs.nixkraken.packages.${pkgs.system}.gk-configure;
  gkTheme = inputs.nixkraken.packages.${pkgs.system}.gk-theme;
  catppuccin = pkgs.local.catppuccin-gitkraken;

  configJson = builtins.toJSON {
    acceptedEULA = true;
    showTutorial = false;
    notifications = { feature = false; help = false; marketing = false; };
    graph = {
      compact = true; showAuthor = true; showDatetime = true;
      showMessage = true; showRefs = false; showSHA = false;
      showGraph = true;
    };
    tools.terminal = "${pkgs.alacritty}/bin/alacritty";
    ui = {
      theme = "catppuccin-mocha.jsonc";
      editor = { tabSize = 2; wrap = true; };
    };
    user = {
      email = identity.email;
      name = identity.displayName;
    };
    gpg = {
      program = "${pkgs.gnupg}/bin/gpg2";
      signCommits = identity.gpgKey or null != null;
      signTags = identity.gpgKey or null != null;
      signingKey = identity.gpgKey or null;
    };
  };

  configFile = pkgs.writeText "gitkraken-config.json" configJson;
in
wlib.wrap {
  package = gitkrakenPkg;
  flags = [ ]; # gitkraken doesn't take a --config flag
  runShell = ''
    # Apply config before launch
    ${gkConfigure}/bin/gk-configure -c '${configJson}'
    ${gkTheme}/bin/gk-theme -i '${catppuccin}/catppuccin-mocha.jsonc'
  '';
}
```

### Step 3: Wire it into our flake

```nix
# modules/flake-parts/features/wrappers.nix (new)
perSystem = { pkgs, system, ... }:
let
  mkUserPackages = userName: userConfig:
    let
      identity = userConfig.identity;
    in {
      gitkraken = mkGitkrakenWrapper { inherit pkgs identity; };
      # ... other wrapped features
    };
in {
  packages = lib.concatMapAttrs (userName: userConfig:
    lib.mapAttrs' (pkg: drv:
      lib.nameValuePair "${userName}.${pkg}" drv
    ) (mkUserPackages userName userConfig)
  ) config.users;
};
```

This gives us `packages.x86_64-linux."sini.gitkraken"`, which `nix run` resolves.

## What we lose vs the HM path

| Concern                    | HM module path                          | Wrapper path                              |
| -------------------------- | --------------------------------------- | ----------------------------------------- |
| Config application         | Activation script, survives reboots     | Applied on each launch (or first launch)  |
| programs.git defaults      | Falls through from HM git config        | We supply values directly                 |
| Persistence                | `home.persistence` manages state dirs   | Not applicable — user manages state       |
| Package deduplication      | HM merges all `home.packages`           | Wrapper bundles its own closure           |
| Theme installation         | Activation script, runs once            | Runs on each launch (fast, idempotent)    |

The persistence loss is fine — `nix run` is for ad-hoc use, not managed state.
The config re-application on each launch is acceptable for gitkraken since
`gk-configure` is fast and idempotent.

## The three approaches to get there

### Approach A: Standalone wrapper (bypass HM module entirely)

Write a wrapper-module from scratch that generates the JSON config and wraps the
binary. Does not import `inputs.nixkraken.homeManagerModules` at all.

**Pros**: Clean, no HM dependency, full control
**Cons**: Duplicates the config shape knowledge from the nixkraken module.
Changes to nixkraken's config format would need manual tracking. We lose the
typed options that nixkraken provides (graph, ui, gpg submodules with
validation).

### Approach B: Evaluate the HM module in a shim (extract config)

Build a minimal HM-compatible evaluation context that provides just enough
option declarations for the nixkraken module to evaluate, then extract the
resulting JSON from the evaluated config.

```nix
let
  # Minimal shim providing HM options that nixkraken reads
  hmShim = { lib, ... }: {
    options = {
      home.packages = lib.mkOption { type = lib.types.listOf lib.types.package; default = []; };
      home.activation = lib.mkOption { type = lib.types.attrs; default = {}; };
      programs.git = {
        userEmail = lib.mkOption { type = lib.types.str; default = ""; };
        userName = lib.mkOption { type = lib.types.str; default = ""; };
        signing = {
          signByDefault = lib.mkOption { type = lib.types.bool; default = false; };
          key = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        };
      };
      programs.ssh.enable = lib.mkOption { type = lib.types.bool; default = false; };
    };
  };

  eval = lib.evalModules {
    modules = [
      hmShim
      inputs.nixkraken.homeManagerModules.nixkraken
      {
        programs.nixkraken = {
          enable = true;
          # ... our config ...
        };
      }
    ];
  };

  # Extract the JSON that gk-configure would receive
  configJson = eval.config.programs.nixkraken._submoduleSettings;
  packages = eval.config.home.packages;
  activationScripts = eval.config.home.activation;
in
  # ... build wrapper from extracted config
```

**Pros**: Single source of truth — the nixkraken module's option types and
validation still apply. Config shape changes are automatically picked up.
**Cons**: Fragile — the shim must match every HM option the module touches. If
nixkraken adds a new `config.programs.X` dependency, the shim breaks. The
`home.activation` extraction is messy (it's DAG-typed, contains shell scripts
with store path references). Also, `_submoduleSettings` is internal and could
change.

### Approach C: Fork/extend nix-wrapper-modules with an HM evaluation adapter

Add first-class HM module evaluation support to nix-wrapper-modules. This is the
generalized version of Approach B — instead of a per-module shim, build a
reusable adapter that can evaluate any HM module in a wrapper context.

```nix
# Hypothetical API (extending nix-wrapper-modules)
wlib.wrapHomeModule {
  inherit pkgs;
  homeModule = inputs.nixkraken.homeManagerModules.nixkraken;
  homeConfig = {
    programs.nixkraken = {
      enable = true;
      # ... our config ...
    };
    # Provide values the module reads from other HM options
    programs.git.userEmail = identity.email;
    programs.git.userName = identity.displayName;
  };
  # What to extract from the evaluation
  extractPackages = true;     # home.packages → wrapper extraPackages
  extractActivation = true;   # home.activation → wrapper runShell
}
```

This adapter would:
1. Import the full HM option declarations (from the home-manager input)
2. Evaluate the target module within that context
3. Extract `home.packages`, `home.activation`, `home.file`, `xdg.configFile`
4. Map them onto wrapper-module equivalents:
   - `home.packages` → `extraPackages`
   - `home.file` / `xdg.configFile` → `constructFiles`
   - `home.activation` → `runShell` (linearize the DAG)

**Pros**: Generalized — works for any HM module, not just nixkraken. Single
source of truth. Makes the entire class of "HM module → wrapped package"
conversions mechanical.
**Cons**: Highest implementation effort. Full HM evaluation is heavy (imports all
option declarations). Activation scripts may reference HM internals
(`$DRY_RUN_CMD`, `$VERBOSE_ARG`). Some HM features (persistence,
`home.sessionVariables` via PAM) don't have wrapper equivalents. Needs
home-manager as an input to nix-wrapper-modules (or provided by the consumer).

## Recommendation

**Start with Approach A** for gitkraken specifically. The config JSON shape is
stable and well-documented by nixkraken's options. The duplication is small —
it's just a JSON object, not logic.

**Prototype Approach C in parallel** as a proof-of-concept. If it works
reliably, it replaces both A and B for all future features. The key risk is
whether `home.activation` DAG scripts can be meaningfully extracted — gitkraken
is actually a good test case since its activation is self-contained
(`gk-configure` and `gk-theme` with no HM variable references).

**Approach B is the worst of both worlds** — as fragile as C but without the
generality. Skip it.

## What the flake output looks like

```
packages.x86_64-linux = {
  "sini.gitkraken"   = <wrapped gitkraken with sini's identity>;
  "sini.alacritty"    = <wrapped alacritty, no identity needed>;
  "shuo.gitkraken"   = <wrapped gitkraken with shuo's identity>;
  # ...
};
```

```bash
nix run .#sini.gitkraken      # launches configured gitkraken as sini
nix run .#alacritty            # launches configured alacritty (no user context)
nix build .#sini.gitkraken     # build the wrapped derivation
```

## Open questions specific to gitkraken

1. **Does gitkraken respect `XDG_CONFIG_HOME`?** If so, we could write config to
   a store-path dir and set `XDG_CONFIG_HOME` in the wrapper, avoiding runtime
   `gk-configure` entirely. This would make the wrapper pure.

2. **Are `gk-configure` and `gk-theme` exposed as packages from the nixkraken
   flake?** If not, we'd need to build the JSON-writing logic ourselves or
   fork nixkraken.

3. **Config mutability**: GitKraken writes to its own config at runtime (e.g.,
   window positions, recently opened repos). A wrapper that forces config on
   every launch would reset these. We may want a "first launch only" or "merge"
   strategy.

4. **Closure size**: The wrapper bundles gitkraken + alacritty + gnupg + git +
   theme. This is fine for `nix run` but worth noting for disk usage if building
   many user variants.

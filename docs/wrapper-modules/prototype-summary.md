# HM Adapter Prototype: Implementation Summary

> Approach C from [gitkraken-case-study.md](./gitkraken-case-study.md) —
> generalized home-manager module evaluation adapter for nix-wrapper-modules.

## What was built

### Files created/modified

| File                       | Purpose                                                                             |
| -------------------------- | ----------------------------------------------------------------------------------- |
| `lib/hm-adapter.nix`       | Core `wrapHomeModule` function (~250 lines)                                         |
| `lib/lib.nix`              | Added `wrapHomeModule` + `hmAdapter` to wlib exports                                |
| `ci/flake.nix`             | Added `home-manager` input; smart arg passing to checks via `builtins.functionArgs` |
| `ci/checks/hm-adapter.nix` | Test: wraps a simple inline HM module, verifies 8 assertions                        |
| `CLAUDE.md`                | Updated architecture section with adapter docs                                      |

### API

```nix
wlib.wrapHomeModule {
  pkgs = pkgs;
  home-manager = inputs.home-manager;
  homeModule = inputs.nixkraken.homeManagerModules.nixkraken;
  mainPackage = pkgs.gitkraken;
  homeConfig = { programs.nixkraken.enable = true; /* ... */ };
  # Optional:
  extraHomeModules = [];
  stateVersion = "24.11";
  extractPackages = true;   # home.packages → extraPackages
  extractActivation = true; # home.activation → runShell
  extractFiles = true;      # home.file / xdg.configFile → derivation files
}
```

Returns a wrapper-module `.config` with `.wrap`/`.apply`/`.eval`/`.wrapper`.

### Extraction mapping

| HM output              | Wrapper equivalent                    | Implementation                                                                         |
| ---------------------- | ------------------------------------- | -------------------------------------------------------------------------------------- |
| `home.packages`        | `extraPackages`                       | Direct filter (exclude `mainPackage` by `toString` comparison)                         |
| `home.activation.*`    | `runShell`                            | DAG-sorted via `lib.toposort`, HM internals filtered out, activation variables stubbed |
| `home.file.*` (text)   | `constructFiles`                      | Text embedded via `passAsFile` mechanism                                               |
| `home.file.*` (source) | `buildCommand` + `drv` attrs          | Source paths added as drv attributes for dependency tracking                           |
| `xdg.configFile.*`     | Same as above + `env.XDG_CONFIG_HOME` | Files placed in `$out/hm-xdg-config/`, env var set with `mkDefault`                    |

## Gotchas and learnings

### 1. String context loss with HM `source` paths

**Problem:** HM `home.file` entries with `source` (store-path derivations) lost
their Nix string context when referenced in the wrapper derivation's
`buildCommand`. The remote builder couldn't find the source files because they
weren't tracked as build dependencies.

**Root cause:** The source derivation paths, when accessed from the evaluated HM
config and interpolated into strings, lost their dependency-tracking string
context somewhere in the HM module system's processing.

**Solution:** Split file extraction into two paths:

- **Text entries** (`text != null`): Use `constructFiles`, which embeds content
  directly via `passAsFile` — no external dependency needed.
- **Source entries** (store paths): Add source paths as explicit derivation
  attributes via `drv = sourceDrvAttrs`. This guarantees Nix tracks them as
  build inputs. The build script references them via shell variable expansion
  (`${entry.attrName}`).

### 2. `constructFiles` key naming requirements

**Problem:** `constructFiles` keys become `passAsFile` entries, which become
bash variables (`${key}Path`). HM file names like
`/homeless-shelter/.cache/.keepPath` produce invalid bash variable names
(contain `/`, `.`, `-`).

**Solution:** Aggressive sanitization — replace all non-alphanumeric characters
with underscores, ensure the result starts with a letter or `_`. Prefix all keys
with `hm_` for namespace safety.

### 3. HM `xdg.configFile` target normalization

**Problem:** XDG config file targets in HM can appear in three different forms
depending on context:

- Absolute: `/homeless-shelter/.config/test-app/config.ini`
- Relative to HOME: `.config/test-app/config.ini`
- Bare (just the name): `test-app/config.ini`

**Solution:** `normalizeXdgTarget` strips all known prefixes (`xdgConfigHome/`,
`homeDir/.config/`, `.config/`) to produce bare relative paths suitable for
placement under `$out/hm-xdg-config/`.

### 4. HM internal file/activation deduplication

**Problem:** HM merges `xdg.configFile` entries into `home.file` under the
attribute name `${xdg.configHome}/${name}`. Extracting both would duplicate
files. HM also creates internal activation entries (`writeBoundary`,
`linkGeneration`, etc.) and files (`.cache/.keep`, `tray.target`) that don't
belong in a wrapper.

**Solution:**

- **Files:** Filter `home.file` by computing expected merged attribute names and
  excluding them. This is more reliable than target-path matching.
- **Activation:** Hardcoded list of known HM internal entry names to skip.
  User-defined entries (anything after `writeBoundary`) pass through.

### 5. HM `executable` option is nullable bool

**Problem:** `home.file.*.executable` is `null | true | false`. Using
`fileCfg.executable or false` returns `null` (Nix `or` checks attribute
existence, not nullability). `lib.optionalString null "..."` throws.

**Solution:** Use `fileCfg.executable == true` (explicit equality check).

### 6. CI flake check arg passing

**Problem:** Existing checks use strict argument sets `{ pkgs, self }:` (no
`...`). Adding `home-manager` to the import args breaks all existing checks.

**Solution:** Use `builtins.functionArgs` to introspect each check function and
only pass `home-manager` to checks that accept it:

```nix
extraArgs = lib.optionalAttrs ((builtins.functionArgs fn) ? home-manager) {
  inherit home-manager;
};
```

### 7. HM evaluation is heavy but works

`home-manager.lib.homeManagerConfiguration` successfully evaluates arbitrary HM
modules with stub values (`home.username = "wrapper-user"`,
`home.homeDirectory = "/homeless-shelter"`, `home.stateVersion = "24.11"`). The
evaluation pulls in all HM option declarations but this is acceptable — it's a
one-time cost per `wrapHomeModule` call, not per-build.

HM internal modules create files we don't need (`.cache/.keep`,
`environment.d/10-home-manager.conf`, `systemd/user/tray.target`) but these are
harmless in the wrapper derivation.

## Test coverage

The test (`ci/checks/hm-adapter.nix`) wraps a minimal inline HM module that
exercises all three extraction paths:

1. **Packages:** `home.packages = [ pkgs.hello pkgs.cowsay ]` — verifies
   `mainPackage` (hello) is the wrapper binary and cowsay is in `extraPackages`
1. **XDG files:** `xdg.configFile."test-app/config.ini".text = "..."` — verifies
   file extraction, correct path normalization, and `XDG_CONFIG_HOME` env var
1. **Home files:** `home.file.".test-app-home".text = "..."` — verifies non-XDG
   file extraction
1. **Activation:** `home.activation.testActivation` with `$DRY_RUN_CMD` —
   verifies script extraction and variable stubbing

## Known limitations

1. **Activation scripts run on every launch** — not just once. Fine for
   idempotent scripts (like `gk-configure`) but may be undesirable for others.
1. **`XDG_CONFIG_HOME` override is global** — redirects ALL XDG config lookups
   to the wrapper derivation. Override via
   `.wrap { env.XDG_CONFIG_HOME = ...; }`.
1. **HM features without wrapper equivalents are ignored** — `home.persistence`,
   `systemd.user.services`, `home.sessionVariables`, etc.
1. **Activation scripts referencing `$newGenPath`/`$oldGenPath`** find them
   empty.
1. **HM internal files leak into the wrapper** — `.cache/.keep`, `tray.target`,
   etc. Harmless but present.
1. **`home-manager` is now a CI dependency** — added to `ci/flake.nix` inputs.
   The core library remains independent.

## Next steps

1. **Test with nixkraken** — the motivating use case. This requires
   `inputs.nixkraken` and a real `programs.git` config.
1. **Test with simple HM modules** — `programs.bat`, `programs.starship` etc. to
   validate the `xdg.configFile` path works end-to-end.
1. **Source-only file dependency tracking** — verify the `drv` attribute
   approach works for HM modules that set `source` directly (not via `text`).
1. **Activation script categorization** — distinguish build-time vs runtime
   scripts for more precise extraction.
1. **`home.sessionVariables`** extraction → `env` mapping (straightforward
   addition).

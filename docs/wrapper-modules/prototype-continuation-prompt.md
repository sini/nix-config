# Continuation prompt: nix-wrapper-modules HM adapter — design review & next steps

## Context for the agent

You are picking up work on a **home-manager module evaluation adapter** for
[nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules), a Nix
library that produces wrapped package derivations using the NixOS module system.

A working prototype has been implemented. Your job is to **review its design,
validate it against real-world HM modules, harden edge cases, and plan the
integration path** into the consuming NixOS config at
`~/Documents/repos/sini/nix-config`.

## Repositories

| Repo                       | Path                                         | Branch | State                                   |
| -------------------------- | -------------------------------------------- | ------ | --------------------------------------- |
| nix-wrapper-modules (fork) | `~/Documents/repos/sini/nix-wrapper-modules` | `main` | Prototype committed, all CI checks pass |
| nix-config (consumer)      | `~/Documents/repos/sini/nix-config`          | —      | Design docs only, no integration yet    |

## Required reading (in order)

Read these files before doing anything else:

1. **Design context & tier classification:**
   `~/Documents/repos/sini/nix-config/docs/wrapper-modules/observations.md`

1. **Motivating case study (GitKraken via nixkraken HM module):**
   `~/Documents/repos/sini/nix-config/docs/wrapper-modules/gitkraken-case-study.md`

1. **Prototype implementation summary (gotchas, learnings, known limitations):**
   `~/Documents/repos/sini/nix-config/docs/wrapper-modules/prototype-summary.md`

1. **The adapter implementation itself:**
   `~/Documents/repos/sini/nix-wrapper-modules/lib/hm-adapter.nix`

1. **The passing test:**
   `~/Documents/repos/sini/nix-wrapper-modules/ci/checks/hm-adapter.nix`

1. **Existing wrapper-modules architecture (for context):**
   `~/Documents/repos/sini/nix-wrapper-modules/CLAUDE.md`
   `~/Documents/repos/sini/nix-wrapper-modules/lib/lib.nix`
   `~/Documents/repos/sini/nix-wrapper-modules/lib/core.nix`

## What exists today

`wlib.wrapHomeModule` takes an arbitrary HM module, evaluates it in a real
`homeManagerConfiguration` context with stub values, extracts side effects, and
maps them to wrapper-module primitives:

- `home.packages` → `extraPackages` (minus caller-specified `mainPackage`)
- `home.activation` → `runShell` (DAG-sorted, HM internals filtered, vars
  stubbed)
- `home.file` (text) → `constructFiles` (embedded via `passAsFile`)
- `home.file` (source) → `buildCommand` copy + explicit `drv` attrs for dep
  tracking
- `xdg.configFile` → same as above + `env.XDG_CONFIG_HOME` (with `mkDefault`)

Returns a wrapper-module `.config` with `.wrap`/`.apply`/`.eval`/`.wrapper`.

The test wraps a trivial inline HM module (hello + cowsay packages, one xdg
config file, one home file, one activation script) and passes 8 assertions. All
existing CI checks continue to pass.

## What needs to happen next

### Phase 1: Design review & hardening (in nix-wrapper-modules)

1. **Review the file extraction approach.** The current split between
   `constructFiles` (text) and `buildCommand` + `drv` attrs (source) was forced
   by string context loss. Is there a cleaner way? Are the `drv` attr names
   (`hmSrc_*`) collision-safe? Will this scale to modules with many files?

1. **Review the XDG_CONFIG_HOME strategy.** Setting it globally via `mkDefault`
   works but redirects ALL XDG lookups. Consider: should it be opt-in instead of
   opt-out? Should there be a per-app subdirectory strategy? What happens when a
   wrapped program also reads `~/.config/fontconfig/` or GTK themes?

1. **Review activation script handling.** The hardcoded `hmInternalEntries` list
   is fragile — new HM versions may add entries. Should we use a positive filter
   (only include entries that come after `writeBoundary`) instead of a negative
   one? How should we handle activation scripts that are NOT idempotent?

1. **HM internal file leakage.** The wrapper currently includes `.cache/.keep`,
   `systemd/user/tray.target`, `environment.d/10-home-manager.conf` etc. These
   are harmless but wasteful. Should we filter them? By what criteria?

1. **Source-only file dependency tracking.** The prototype hasn't been tested
   with HM modules that set `home.file.*.source` directly (not via `text`). The
   `drv` attribute approach for dependency tracking needs validation with a real
   module.

1. **Add more test cases:**
   - A module that uses `source` (not `text`) for files
   - A module with multiple activation scripts in a DAG
   - A module that reads from `config.programs.git` (cross-module dependency)
   - Edge case: module with no packages, no files, just activation
   - Edge case: `mainPackage` appears multiple times in `home.packages`

### Phase 2: Real-world validation

7. **Test with nixkraken.** This is the motivating case. It requires:
   - `inputs.nixkraken` flake input
   - `programs.git.userEmail` / `userName` cross-option dependencies
   - `home.activation` scripts that run `gk-configure` and `gk-theme`
   - Does NOT use `home.file` or `xdg.configFile`

1. **Test with a simple programs.\* module.** Try `programs.bat` or
   `programs.starship` — these use `xdg.configFile` for their config and are
   Tier 1 (no external context needed). Verify that the wrapped program actually
   finds and uses the extracted config.

1. **Test with programs.git.** This is a Tier 2 module — it reads
   `user.identity`, has conditional includes, generates gitconfig. Verify that
   `homeConfig` can supply all needed cross-option values and the resulting
   wrapper works.

### Phase 3: nix-config integration

10. **Design the flake-parts integration.** How should `wrapHomeModule` be
    invoked from `nix-config`? Options from `observations.md`:
    - Per-feature `wrapper` field on the feature module
    - Parallel `wrappers.<name>` registry
    - Automatic scanning of features with `wrapper.enable = true`

1.  **Wire up a Tier 1 pilot.** Pick alacritty or starship. Add
    `nix-wrapper-modules` as a flake input to nix-config, create the wrapper,
    verify `nix run .#alacritty` works.

1.  **Wire up a Tier 2 pilot.** GitKraken or git. Thread identity through
    `homeConfig`. Verify `nix run .#sini.gitkraken` works.

## Key design questions to resolve

- **Should `wrapHomeModule` live in nix-wrapper-modules or in nix-config?** It's
  currently in the fork. Upstream may or may not want an HM dependency in CI.
  Consider keeping it in a separate flake module or in nix-config's lib.

- **Should `home.sessionVariables` be extracted?** They map cleanly to wrapper
  `env` but may conflict with existing env vars. Low-hanging fruit if desired.

- **Activation script first-launch semantics.** For programs like gitkraken
  where config is written to `~/.gitkraken/`, running `gk-configure` on every
  launch resets user-made changes. Should the wrapper support a "first launch
  only" guard (e.g., check for a sentinel file)?

- **Should we filter HM internal home.file entries?** Candidates for filtering:
  files matching `.cache/.keep`, `.local/state/.keep`,
  `environment.d/10-home-manager.conf`, `systemd/user/tray.target`. Or should we
  just accept the noise?

## Commands

```bash
# In ~/Documents/repos/sini/nix-wrapper-modules:
nix fmt                          # Format (nixfmt-tree)
nix flake check -Lv ./ci         # Run all tests
nix build ./ci#checks.x86_64-linux.hm-adapter -L  # Run just the adapter test

# Inspect a wrapper derivation:
nix build ./ci#checks.x86_64-linux.hm-adapter -L 2>&1 | grep "find"
nix log ./ci#checks.x86_64-linux.hm-adapter      # Full test log
```

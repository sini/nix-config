# Prototype Prompt: HM Evaluation Adapter for nix-wrapper-modules

> Feed this to a Claude Code session rooted in your fork of
> `BirdeeHub/nix-wrapper-modules`.

---

## Context

You are working on a fork of
[nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules) — a Nix
library that produces wrapped package derivations using the NixOS module system.
Each wrapper is evaluated via a standalone `lib.evalModules` call and outputs a
plain derivation.

The consuming project is a NixOS homelab config at
`~/Documents/repos/sini/nix-config`. Read the following files there for full
design context before starting implementation:

- `~/Documents/repos/sini/nix-config/docs/wrapper-modules/observations.md` —
  Feature tier classification, adapter architecture overview, integration points
- `~/Documents/repos/sini/nix-config/docs/wrapper-modules/gitkraken-case-study.md`
  — Deep dive into the specific obstacles of wrapping an HM-dependent feature,
  three approaches analyzed (we are implementing Approach C)

## Goal

Add a **generalized home-manager module evaluation adapter** to
nix-wrapper-modules. The adapter takes an arbitrary home-manager module (like
`inputs.nixkraken.homeManagerModules.nixkraken`), evaluates it in a real HM
context, and extracts its side effects into wrapper-module equivalents —
producing a standalone wrapped package derivation.

Target API:

```nix
wlib.wrapHomeModule {
  inherit pkgs;

  # The home-manager input (for option declarations)
  home-manager = inputs.home-manager;

  # The HM module to wrap
  homeModule = inputs.nixkraken.homeManagerModules.nixkraken;

  # Config to set inside the HM evaluation
  homeConfig = {
    programs.nixkraken = {
      enable = true;
      acceptEULA = true;
      skipTutorial = true;
      notifications = { feature = false; help = false; marketing = false; };
      graph = { compact = true; showAuthor = true; showDatetime = true; };
      user = { email = "sini@example.com"; name = "sini"; };
      gpg = { signCommits = true; signingKey = "0xABC123"; };
    };
    # Values that the module reads from other HM options
    programs.git.userEmail = "sini@example.com";
    programs.git.userName = "sini";
  };

  # Optional: extra modules to import into the HM evaluation
  extraHomeModules = [ ];

  # Control what gets extracted (all default true)
  extractPackages = true;     # home.packages → wrapper extraPackages
  extractActivation = true;   # home.activation → wrapper runShell (pre-launch)
  extractFiles = true;        # home.file / xdg.configFile → constructFiles
}
```

The return value should be a wrapped package derivation (or a wrapper-module
config that can be further extended via `.wrap`/`.apply`).

## The Problem

HM modules and wrapper-modules have incompatible evaluation contexts:

- **HM modules** declare options in the HM namespace (`home.packages`,
  `home.activation`, `home.file`, `xdg.configFile`, `programs.*`) and produce
  config there. They expect the full HM module system.
- **Wrapper-modules** use an independent `lib.evalModules` with their own option
  namespace (`package`, `flags`, `env`, `constructFiles`, `buildCommand`). They
  know nothing about HM.

You cannot import an HM module into a wrapper evaluation — the option
declarations don't exist. The adapter must bridge this gap.

## Implementation Strategy

### Step 1: Evaluate the HM module in a real HM context

Use home-manager's own module system to evaluate the target module. Home-manager
exposes its option declarations — import them to create a valid evaluation
context, then layer the user's `homeConfig` on top.

Key consideration: home-manager's `lib.hm.dag` types are used for
`home.activation` entries. The evaluation must handle these properly.

You need to figure out the minimal viable HM evaluation. The full
`home-manager.lib.homeManagerConfiguration` may be too heavy (it wants
`home.username`, `home.homeDirectory`, `home.stateVersion`, etc.). Investigate
whether you can:

1. Use `lib.evalModules` with just the HM module declarations imported
1. Provide stub values for required HM options
   (`home.username = "wrapper-user"`,
   `home.homeDirectory = "/homeless-shelter"`, `home.stateVersion = "24.11"`)
1. Or find a lighter-weight entry point in HM's source

### Step 2: Extract HM side effects

After evaluation, read from the HM config and map to wrapper-module concepts:

| HM output                 | Wrapper equivalent                   | Notes                                                                                                                                                                                                 |
| ------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `home.packages`           | `extraPackages`                      | Direct — list of derivations to add to PATH                                                                                                                                                           |
| `home.file.<name>.source` | `constructFiles`                     | Store-path files to include in the wrapper                                                                                                                                                            |
| `xdg.configFile.<name>`   | `constructFiles`                     | Same, under `$XDG_CONFIG_HOME`                                                                                                                                                                        |
| `home.activation.<name>`  | `buildCommand` or wrapper `runShell` | DAG entries containing shell scripts. These need linearization. Some run at activation time (impure — write to `$HOME`) and some generate store-path artifacts. The adapter should distinguish these. |

### Step 3: Produce a wrapper-module config

Feed the extracted data into nix-wrapper-modules' existing primitives:

```nix
# Pseudocode for the adapter output
{
  package = mainPackage;  # from home.packages (the "primary" one)
  extraPackages = otherPackages;
  constructFiles = extractedFiles;
  # For activation-style config (like gitkraken's gk-configure):
  # Generate a wrapper startup script that applies config before exec
  buildCommand.hmActivation = {
    data = activationScript;
    after = [ "symlinkScript" ];
  };
}
```

### Step 4: Expose as `wlib.wrapHomeModule`

Add the function to `lib/lib.nix` alongside `wlib.evalModule`,
`wlib.wrapModule`, etc. It should return a wrapper-module evaluation result with
the standard `.wrap`/`.apply`/`.eval` interface, so consumers can further extend
it.

## Key Challenges to Solve

### 1. Identifying the "main package"

`home.packages` is a flat list. For gitkraken, it contains the gitkraken binary,
git, gnupg, alacritty, and a login helper. The adapter needs to know which one
is the "main" package (the one to wrap). Options:

- Require the caller to specify it (simplest, most reliable)
- Heuristic: match by name against the module name
- Let the caller filter `home.packages` into main vs extra

Recommend: require `mainPackage` as an explicit argument.

### 2. Activation script extraction

HM activation scripts use `lib.hm.dag.entryAfter` for ordering. They contain
shell commands with references to store paths. For the wrapper use case, these
fall into two categories:

- **Store-path generating** (e.g., write a config file to a temp dir, then
  reference it) — these should run at **build time** in the wrapper's
  `buildCommand`
- **Impure / stateful** (e.g., `gk-configure` writing to `~/.gitkraken/`) —
  these should run at **launch time** in the wrapper's startup script

For the prototype, treat all activation scripts as launch-time (run before
exec). This is correct for gitkraken and most apps. Build-time extraction can
come later.

HM activation scripts may reference these variables:

- `$HOME` — user's home directory (available at runtime)
- `$DRY_RUN_CMD` — empty string in real runs, `echo` in dry runs. Replace with
  empty string.
- `$VERBOSE_ARG` — `-v` or empty. Replace with empty string.
- `$newGenPath`, `$oldGenPath` — HM generation paths. These don't apply in
  wrapper context. May need stubbing or filtering.

### 3. HM module dependencies on other HM options

Some HM modules read from other `programs.*` options as defaults:

- nixkraken reads `config.programs.git.userEmail`,
  `config.programs.git.signing.key`
- Some modules read `config.programs.ssh.enable`

The `homeConfig` parameter lets callers set these. But if a module does a deep
read (e.g., `config.services.gpg-agent.enable`), the caller needs to know. The
adapter should provide clear error messages when an option is accessed but not
declared.

### 4. Keeping home-manager as an optional dependency

nix-wrapper-modules should not hard-depend on home-manager. The adapter should
accept `home-manager` as a parameter (the caller provides their HM input). The
core library stays independent.

Suggested file structure:

```
lib/
  lib.nix           # existing — core wlib functions
  hm-adapter.nix    # NEW — wrapHomeModule implementation
modules/
  hmAdapter/        # NEW — optional module for HM extraction
```

## Test Case: GitKraken

The nixkraken HM module (`nicolas-goudry/nixkraken`) is the motivating test
case:

- Declares `programs.nixkraken` with typed submodule options (graph, git, gpg,
  ssh, tools, ui, user, notifications)
- Installs packages via `home.packages` (gitkraken binary, git, gnupg, editor,
  terminal, a `gk-login` helper)
- Applies config via `home.activation` scripts that run
  `gk-configure -c '<JSON>'` and `gk-theme -i '<paths>'`
- Reads defaults from `config.programs.git` and `config.programs.ssh`
- Does **not** use `home.file` or `xdg.configFile`

A successful prototype should be able to produce a wrapped gitkraken derivation
from this module that, when run, applies the JSON config and launches gitkraken.

## Deliverables

1. **`lib/hm-adapter.nix`** — the `wrapHomeModule` function
1. **A test/example** — wrap the nixkraken HM module (or a simpler HM module you
   create for testing) and verify the output derivation works
1. **Documentation** — update the README or add a doc explaining the HM adapter
   API and its limitations

## What NOT to do

- Don't modify the core wrapper-module evaluation (`lib/core.nix`) unless
  necessary — extend, don't rewrite
- Don't try to handle every HM feature. Start with `home.packages`,
  `home.activation`, `home.file`, and `xdg.configFile`. Ignore
  `home.persistence`, `home.sessionVariables`, `systemd.user.services`, and
  other system-integration features — these don't have wrapper equivalents
- Don't hard-code anything gitkraken-specific in the adapter — it should be
  generic enough that wrapping a simple HM module (e.g., one that just sets
  `programs.bat.enable = true` and `programs.bat.config.theme = "catppuccin"`)
  also works

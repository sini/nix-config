# Panix battery

The panix battery builds a [panix](https://github.com/mihakrumpestar/panix)
`panix.yml` from `den.hosts`, plus a `panix` command that always runs on the
config from the current eval. It sits next to colmena and reads the same host
entities.

Files, each where the repo keeps that kind of piece:

- `modules/den/batteries/panix/panix.nix`: the battery. It covers the
  `den.hosts` → fleet mapping, the battery options, the wrapper, the devshell
  command, the flake input and the files sink.
- `modules/den/batteries/panix/settings.nix`: the typed panix.yml settings
  (`den.panix.fleets.<system>`, schema v0.11.0) and their rendering
  (`den.panix.render`). This panix option module was contributed by theutz
  (Matrix).
- `modules/den/batteries/panix/hardened.nix`: the hardened rules
  (`den.panix.hardened`, `den.panix.violations`) and the `panix-hardened` check.
- `modules/den/classes/panix.nix`: the opt-in `panix` class.
- `modules/den/policies/panix.nix`: per-host capture of `panix` class fragments.
- `modules/den/defaults.nix` (the `den.panix` block): this fleet's values.
  Nothing else in the feature is site-specific.

All of these are ordinary modules that import-tree loads. They reach each other
through `config.den.panix.*`, and none of them imports another by path.

Each example below is marked **evaluated** or **not evaluated**. Evaluated means
I built it with `nix build .#panix-config` and read the output back.

## Quick start

You need den, flake-parts, and [flake-file](https://github.com/vic/flake-file),
which the battery uses to declare the `panix` flake input. You also need inputs
named `nixpkgs-unstable` and `flake-utils`, because the panix input follows
them. The devshell command also needs numtide/devshell and this repo's
`devshell` den class (`modules/den/classes/devshell.nix`). I have not tested the
battery in any other repo.

1. Put the files above somewhere your modules are imported. This repo
   auto-imports `modules/`.
2. Enable it and set your site rules. This example is **evaluated**: it is the
   `den.panix` block in `modules/den/defaults.nix`.

   ```nix
   den.panix = {
     enable = true;
     flakeName = "nix-config";
     hostAddress =
       host:
       if host.ipv4 == [ ] then
         "${host.name}.ts.${config.den.environments.${host.environment}.domain}"
       else
         builtins.head host.ipv4;
     hostUser = host: host.remote-deployment-user or "sini";
     hostTags = host: [ host.environment ];
     settings.flags.skip_phases = [ "bootstrap" ];
   };
   ```

3. Regenerate the flake inputs: `nix run .#write-flake`, then lock.
4. Add `/.panix` to `.gitignore`, since that is the wrapper's state directory.
5. Run it from the devshell, or with `nix run .#panix -- …`:

   ```sh
   panix deploy -t cortex          # one host
   panix deploy -t prod            # a tag (see Tags)
   panix deploy --dry-run          # config-only preview, contacts no host
   nix build .#panix-config        # read the rendered panix.yml
   ```

## Options (`den.panix.*`)

| Option           | Default                                               | What it does                                                                                                                                                                                                |
| ---------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enable`         | `false`                                               | Turns the battery on. You get `packages.<system>.panix-config` and `packages.<system>.panix`, the flake input, and the devshell command.                                                                    |
| `flakeName`      | `"self"`                                              | The key under `fleet.flakes`, which panix also registers as a tag. Must match `[a-z0-9-]+`.                                                                                                                 |
| `flakeUrl`       | `null`                                                | `fleet.flakes.<flakeName>.url`. With `null`, the wrapper fills in `git+file://<repo root>` at run time. Example: `"github:owner/repo"`.                                                                     |
| `hosts`          | `host: builtins.elem host.class [ "nixos" "darwin" ]` | Takes a host entity and returns whether it is in the fleet. Hosts with no flake output (`intoAttr = [ ]`, such as microvm guests) are always skipped.                                                       |
| `hostAddress`    | `host: host.name`                                     | Takes a host and returns the machine's `ssh.hostname`.                                                                                                                                                      |
| `hostUser`       | none (required)                                       | Takes a host and returns the machine's `ssh.username`. It is required because panix would otherwise default to `root`.                                                                                      |
| `hostTags`       | `_: [ ]`                                              | Takes a host and returns extra machine tags, which go in front of the aspect tags.                                                                                                                          |
| `knownHostsFile` | `null`                                                | An absolute path, set as the fleet's `ssh.known_hosts_file`. Put your host CA's `@cert-authority` line in it. `null` uses ssh's own files. Example: `"/etc/ssh/ssh_known_hosts"`.                           |
| `maxConcurrency` | `4`                                                   | `flags.runtime.max_concurrency`. panix's own default of 0 means unlimited.                                                                                                                                  |
| `hardened`       | `true`                                                | Makes eval fail when the merged settings break the [rules](#hardened-checks).                                                                                                                               |
| `settings`       | `{ }`                                                 | A settings module, merged into every `den.panix.fleets.<system>`, for global settings: `flags`, `output_types`, and fleet- or flake-level values. It is always merged, whether or not the class is enabled. |
| `enableClass`    | `false`                                               | Collects `panix` class fragments from each fleet host's aspects ([below](#the-panix-class)). This repo leaves it off.                                                                                       |
| `writeFile`      | `false`                                               | Also writes `panix.yml` into the repo through github:sini/files ([below](#output-sinks)). This needs `flakeUrl`.                                                                                            |

Examples:

- `hosts`, opting hosts in by aspect. **Evaluated**: only the host that had the
  aspect was selected.

  ```nix
  den.panix.hosts = host: host.hasAspect den.aspects.panix-class-test;
  ```

- `settings` at fleet and flake level. **Evaluated**: the rendered YAML had
  `fleet.auto_rollback: true` and
  `fleet.flakes.nix-config.nix.copy_flags: [--compress]`.

  ```nix
  den.panix.settings = {
    fleet.auto_rollback = true;
    fleet.flakes.nix-config.nix.copy_flags = [ "--compress" ];
  };
  ```

Settings are typed. An unknown key or a wrong type fails at eval time.
**Evaluated**: `fleet.bogus = 1` gave "The option
`den.panix.fleets.x86_64-linux.fleet.bogus' does not exist". Only top-level keys are freeform, which panix's schema also allows. For the full option reference, read `batteries/panix/settings.nix`.

## What the battery emits, and where

Each host gets one installable at its own flake output, `host.intoAttr`
(`nixosConfigurations.<name>` or `darwinConfigurations.<name>`), with a single
machine named `<name>`. Every value below is set with `mkDefault`, at the level
where panix reads it:

| Level       | Field                           | Value                                                                                                                                                                                              |
| ----------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| flags       | `local_machine_hostname`        | `panix-no-local-machine.invalid`. panix decides that a machine is local by comparing hostname strings, so this sentinel means no machine is ever treated as local, and every deploy goes over SSH. |
| flags       | `runtime.max_concurrency`       | `maxConcurrency`                                                                                                                                                                                   |
| fleet       | `ssh.disable_auto_add_host_key` | `true`. Without it, panix puts `StrictHostKeyChecking=accept-new` before `extra_flags`, and ssh keeps the first value it sees.                                                                     |
| fleet       | `ssh.extra_flags`               | `-o StrictHostKeyChecking=yes -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15`                                                                                                     |
| fleet       | `ssh.known_hosts_file`          | `knownHostsFile`, when it is set                                                                                                                                                                   |
| fleet       | `bootstrap.disable_nix_install` | `true`                                                                                                                                                                                             |
| fleet       | `auto_rollback`                 | `false`                                                                                                                                                                                            |
| flake       | `url`                           | `flakeUrl`, or a placeholder that the wrapper fills in                                                                                                                                             |
| installable | `nix.build_mode`                | `"remote"` when `host.system` differs from the deployer system, otherwise `"local"`. Installable is the lowest level where panix accepts `build_mode`.                                             |
| machine     | `ssh.hostname`, `ssh.username`  | `hostAddress host`, `hostUser host`                                                                                                                                                                |
| machine     | `tags`                          | `hostTags host ++` the host's resolved named aspects by identity path (for example `roles/workstation`), sorted and deduplicated, the same as colmena                                              |

The battery sets nothing else, so panix's own fleet → flake → installable →
machine inheritance applies to every other field. Inheritance in panix never
overrides: a child level fills only the fields it leaves unset, and lists
append. That means a `true` set at a parent level cannot be switched back off
lower down.

The deployer system is the `<system>` of the package.
`packages.x86_64-linux.panix-config` builds the darwin host remotely and the
Linux hosts locally, and `packages.aarch64-darwin.panix-config` does the
reverse. **Evaluated**, both.

### Tags

panix also registers the flake name, the output type, the installable name and
the machine name as tags. Tags accumulate; they never override. So
`-t nixosConfigurations`, `-t cortex`, `-t prod` and `-t roles/workstation` all
work.

## The `panix` class

The class is off by default, and this fleet keeps it off. The plan is for
per-aspect deploy data to come later from tool-neutral quirks that this adapter
reads, the same choice the repo made for colmena. Another fleet can turn it on:

```nix
den.panix.enableClass = true;
```

Each fleet host then contributes the `panix` class content of every aspect it
includes. A fragment is a settings module for the whole file. It is merged with
module semantics on top of the defaults above. Fragments get two arguments:

- `host`, the den host entity, which den applies.
- `panixPath`, a function from a host to
  `{ flake, outputType, installable, machine }`, the keys of that host's entry.

Installable level and machine level, on the host's own aspect. **Evaluated**:
the values appeared only under cortex's entry.

```nix
den.aspects.cortex.panix =
  { host, panixPath, ... }:
  let
    p = panixPath host;
  in
  {
    fleet.flakes.${p.flake}.installables.${p.outputType}.${p.installable} = {
      activation_mode = "boot"; # installable level
      machines.${p.machine}.activation_hooks.post = [ "echo deployed ${host.name}" ]; # machine level
    };
  };
```

From any included aspect. **Evaluated**: only the host that included the aspect
got `auto_rollback`.

```nix
den.aspects.panix-class-test.panix =
  { host, panixPath, ... }:
  let
    p = panixPath host;
  in
  {
    fleet.flakes.${p.flake}.installables.${p.outputType}.${p.installable}.machines.${p.machine}.auto_rollback = true;
  };
den.aspects.uplink.includes = [ den.aspects.panix-class-test ];
```

A fragment can also set fleet- or flake-level keys, but global values belong in
`den.panix.settings`.

## Overriding a default, and conflicts

The emitted values are `mkDefault`, so a fragment or `settings` value at normal
priority already replaces them, and `mkForce` works too. **Evaluated** on blade:
both replaced the defaults.

```nix
machines.${p.machine} = {
  ssh.hostname = lib.mkForce "forced.example";
  ssh.username = "plain-override";
};
```

When two definitions of the same scalar have the same priority, the module
system raises an error. **Evaluated**: two aspects on cortex set
`activation_mode` to `"boot"` and `"switch"`.

```
The option `den.panix.fleets.x86_64-linux.fleet.flakes.nix-config.installables.nixosConfigurations.cortex.activation_mode'
has conflicting definition values:
- In `panix@cortex/{host=cortex}': "boot"
- In `panix@panix-conflict/{host=cortex}': "switch"
```

To settle it, raise one of them with `lib.mkForce` (**evaluated**: the result
was `switch`) or lower the other with `lib.mkDefault`. Lists at the same
priority are concatenated.

Machine `tags` is an emitted default, so a fragment that sets machine-level
`tags` replaces the aspect tags instead of adding to them. To add tags, set them
at installable level, where panix unions tags across levels. That behaviour
comes from the panix docs; I have not evaluated it here.

## Hardened checks

With `hardened = true` (the default), eval fails with a list of every violation
in the final merged settings. Each rule follows the panix review of 2026-10-16
(commit 414806c). Set `den.panix.hardened = false` to turn the checks off on
purpose.

| Rule                                                                                                       | Reason                                                                                                          |
| ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| no `disable_strict_key_checking = true`, anywhere                                                          | It turns off host key verification.                                                                             |
| no `extra_flags` containing `StrictHostKeyChecking=no` or `=accept-new`, or `UserKnownHostsFile=/dev/null` | A child's flags come before the fleet's, and ssh keeps the first value, so these would undo the strict setting. |
| `flags.skip_phases` must not contain `inspect`                                                             | Without inspect, a live host looks unprovisioned.                                                               |
| no `force_bootstrap`, `force_bootstrap_kexec` or `allow_destructive_actions` above machine level           | A `true` at a parent level reaches every machine below it and can't be overridden lower down.                   |
| no `bootstrap.ssh`                                                                                         | Bootstrap SSH has weaker host-key handling and doesn't belong in an everyday deploy config.                     |
| no `hardware_config_path`                                                                                  | It writes output from the target into the flake.                                                                |
| `build_mode = "remote"` needs exactly one machine on that installable (inherited build modes count)        | The build runs on the first machine and is then copied to the others, peer to peer.                             |
| no literal `{{` in any key or string                                                                       | panix runs the whole file through a template engine before it parses it.                                        |
| flake, installable and machine names must match `[a-z0-9-]`                                                | These names end up in ssh arguments, socket paths and tags.                                                     |

**Evaluated**: one config breaking all of these failed with nine messages, one
per rule. The same config built once `hardened = false` was set.
`checks.<system>.panix-hardened` keeps this as a fixture that breaks each rule
once, and it fails if a rule stops firing or a clean config gets flagged.

## Output sinks

- **Store config plus the wrapper.** `packages.<system>.panix-config` is the
  rendered file. `packages.<system>.panix`, which is also the devshell command,
  does the following:
  - finds the repo root, from `$PRJ_ROOT` or else git's toplevel;
  - creates `<root>/.panix` with mode 0700 and `cd`s into it, so panix's logs,
    snapshots and outlinks land there;
  - writes `<root>/.panix/panix.yml` (mode 0600), a copy of the store config
    with the flake url set to `git+file://<root>`;
  - sets `TMPDIR` to a private 0700 directory, `$XDG_RUNTIME_DIR/panix` (falling
    back to `<root>/.panix/tmp`), because panix puts its ssh control sockets in
    `TMPDIR` and would otherwise use the shared `/tmp`. The runtime directory
    comes first because a socket path has to stay under about 104 bytes, and a
    deep checkout's `.panix` can go past that;
  - runs panix with `PANIX_CONFIG` pointing at that file.

  `PANIX_CONFIG` is panix's environment form of `-c`/`--config`. In 0.11.0 `-c`
  is a per-subcommand flag (`panix -c f deploy` fails), so the environment
  variable is what covers every subcommand. If you export `PANIX_CONFIG`
  yourself, that file is used as-is, after its path is made absolute. `-c` paths
  you pass yourself are resolved inside `.panix`. **Evaluated**: running
  `panix template` and `panix deploy --dry-run` from `modules/` (through
  `nix run`) gave `url: git+file://<repo root>`, a 700 state directory, a 600
  config and `ControlPath=/run/user/1000/panix/panix-ssh-…`. With
  `XDG_RUNTIME_DIR` unset, the wrapper created `.panix/tmp` at 700.

- **Committed file** (`writeFile = true`). This sets
  `files.file."panix.yml".source = <panix-config>` for github:sini/files. It
  needs `flakeUrl`, because a committed file has no wrapper to fill the url in;
  without it, eval fails with that message (**evaluated**). With `flakeUrl` set,
  the generated `write-files` script picks up `panix.yml` (**evaluated**; I did
  not run the writer). sini/files also adds a check that the committed file is
  current. The file reflects whichever system wrote it (see `build_mode` above).

### The store-path config and relative paths

panix 0.11.0 resolves relative paths against its working directory, not against
`panix.yml`'s location. That includes the flake url, which defaults to `.`. The
battery therefore never emits a relative path, and the wrapper fixes the working
directory to `.panix`. If you set paths yourself (`identity_file`,
`out_links_dir`, `snapshot.dir`, `log_file`), make them absolute. Templating
such as `{{ env "X" }}` is refused by the hardened `{{` rule.

## Out of scope

- **Secrets.** The battery emits no panix `secrets` transfers. This fleet's
  secrets are agenix in modules, so the deployed closure equals a plain flake
  build. The typed options still exist for other fleets.
- **Bootstrap.** kexec, disko, `disk_encryption_keys` and `hardware_config_path`
  are not modelled. Nix auto-install is off (`disable_nix_install`), and this
  fleet skips the phase entirely (`flags.skip_phases = [ "bootstrap" ]`).
- **Darwin** is supported. `darwinConfigurations` is a built-in panix output
  type; from a Linux deployer, patch is built on itself.
- **nix-on-droid** is not in the default `hosts`. panix has a
  `nixOnDroidConfigurations` type, but it is untested with this battery.
- **`panix eval`** forces flake validation, which runs `nix eval` on every
  toplevel with a 60 s timeout. A full host eval in this fleet takes longer than
  that, so every installable is reported as "not found". `deploy` does not
  validate flakes by default. Raising `flags.runtime.flake_validation_timeout`
  should help but is not evaluated.
- **Local deploys** go over SSH as well, because of the `local_machine_hostname`
  sentinel. The deploying host needs to accept its own SSH login.

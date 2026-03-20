# ACL: Unified Access Control

## Overview

Groups are the single primitive for access control. They can contain users and
other groups (transitive membership, matching Kanidm's native model). Groups are
defined once in a shared top-level `groups` option and consumed by multiple
provisioners — Kanidm OAuth2, Unix system accounts, Kubernetes RBAC.

Access is environment-scoped: `environments.<env>.access` binds users to groups.
Host login is gate-controlled: `environments.<env>.system-access-groups` and
`hosts.<host>.system-access-groups` declare which system-scoped groups grant
Unix account creation. Both lists are merged at resolution time. `system.enable`
and `system.systemGroups` are fully derived — never set directly.

## Three-Level Resolution

```
groups                                    <- shared definitions (kanidm, unix, system scopes)
  |
environments.<env>.access                 <- user -> [group] bindings per environment
  |
environments.<env>.system-access-groups   <- env-wide baseline login gates
  + hosts.<host>.system-access-groups     <- host-specific login gates (merged with env)
  |
resolved user                             <- enable + systemGroups derived from above
```

## Group Schema

```nix
groups.<name> = {
  scope       = "kanidm" | "unix" | "system";
  description = "Human-readable purpose";
  members     = [ "other-group" ... ];  # group-to-group membership
};
```

### Scopes

| Scope | Purpose | Consumed by |
|----------|----------------------------------|------------------------------| |
kanidm | Identity / OAuth2 access grants | Kanidm provisioner | | unix | Unix
system groups (extraGroups) | NixOS user account setup | | system | Host login
gates | system-access-groups resolution |

### Example Groups

```nix
groups = {
  # --- Identity (kanidm) ---
  admins = { scope = "kanidm"; description = "Full administrative access"; };
  users  = { scope = "kanidm"; description = "Standard user access"; members = [ "admins" ]; };

  # --- System login gates (opt-in — not inherited from identity groups) ---
  system-access      = { scope = "system"; description = "Login access to all hosts"; };
  workstation-access = { scope = "system"; description = "Login access to workstations"; members = [ "system-access" ]; };
  server-access      = { scope = "system"; description = "Login access to servers"; members = [ "system-access" ]; };

  # --- Service access (kanidm oauth2) ---
  "grafana.access"        = { scope = "kanidm"; description = "Grafana login"; members = [ "users" ]; };
  "grafana.server-admins" = { scope = "kanidm"; description = "Grafana server admin"; members = [ "admins" ]; };
  "media.access"          = { scope = "kanidm"; description = "Jellyfin access"; members = [ "users" ]; };

  # --- Unix system groups ---
  wheel    = { scope = "unix"; description = "Sudo access"; };
  podman   = { scope = "unix"; description = "Container runtime"; };
  libvirtd = { scope = "unix"; description = "VM management"; };
  audio    = { scope = "unix"; description = "Audio device access"; };
  video    = { scope = "unix"; description = "Video device access"; };
  render   = { scope = "unix"; description = "GPU render access"; };
};
```

## Environment Access Bindings

`environments.<env>.access` maps usernames to lists of group names. A user can
reference groups from any scope. Membership is direct — transitivity is resolved
at consumption time.

```nix
environments.prod.access = {
  sini = [ "admins" "wheel" "podman" "libvirtd" "audio" "video" "render" ];
  shuo = [ "users" "workstation-access" "wheel" "podman" "audio" "video" "render" ];
  will = [ "users" "workstation-access" "wheel" "podman" "audio" "video" "render" ];
  json = [ "admins" ];
  hugs = [ "users" "grafana.server-admins" ];
  greco = [ "users" ];
  # ...
};
```

A user appearing in `environment.access` with any kanidm-scoped group is
provisioned as a Kanidm person. A user not in any environment's access has no
access anywhere.

## Login Gates

Login gates are defined at two levels and merged at resolution time:

- **Environment-level**: `environments.<env>.system-access-groups` — baseline
  gates for all hosts in the environment.
- **Host-level**: `hosts.<host>.system-access-groups` — additional gates
  specific to a host.

The effective gate list is
`unique(env.system-access-groups ++ host.system-access-groups)`.

```nix
# Environment baseline
environments.prod.system-access-groups = [ "system-access" ];
environments.dev.system-access-groups  = [ "system-access" ];

# Host-specific additions
hosts.cortex.system-access-groups  = [ "workstation-access" ];
hosts.blade.system-access-groups   = [ "workstation-access" ];
hosts.patch.system-access-groups   = [ "system-access" ];
hosts.axon-01.system-access-groups = [ "server-access" ];
```

### Role-Based Host Defaults

Host-level defaults are derived from the host's roles:

| Host Role | Default system-access-groups |
|-------------|---------------------------| | workstation | \[
"workstation-access" \] | | dev | [ "workstation-access" ] | | server | \[
"server-access" \] | | (fallback) | [ "system-access" ] |

Hosts can override via explicit `system-access-groups`.

## Resolution Algorithm

For a given host `H` in environment `E`:

1. Read `E.access` to get `{ username -> [ direct-groups ] }`.
1. For each user, resolve transitive memberships using `groups` definitions.
1. **Login check** (derives `system.enable`):
   `(resolved system-scoped groups) ∩ (E.system-access-groups ++ H.system-access-groups) != {}`
1. **Unix groups** (derives `system.systemGroups`): filter resolved groups to
   `scope = "unix"`, extract names.
1. **Kanidm groups**: pass direct group list to Kanidm (Kanidm resolves
   transitivity itself via its own group-to-group membership config).

### Example: sini on cortex

```
direct groups    = [ "admins" "wheel" "podman" "libvirtd" "audio" "video" "render" ]
transitive       = [ "admins" "users" "system-access" "workstation-access"
                     "server-access" "grafana.access" "media.access" ... ]
                   ++ [ "wheel" "podman" "libvirtd" "audio" "video" "render" ]

dev.system-access-groups    = [ "system-access" ]
cortex.system-access-groups = [ "workstation-access" ]
merged gates                = [ "system-access" "workstation-access" ]
system-scoped resolved = [ "system-access" "workstation-access" "server-access" ]
intersection           = [ "system-access" "workstation-access" ]  -> enable = true

unix-scoped resolved   = [ "wheel" "podman" "libvirtd" "audio" "video" "render" ]
                       -> systemGroups = [ "wheel" "podman" "libvirtd" "audio" "video" "render" ]
```

### Example: json on cortex

```
direct groups    = [ "admins" ]
transitive       = [ "admins" "users" "grafana.access" "media.access" ... ]

unix-scoped      = []  -> no unix groups
system-scoped    = []  -> no system groups (system-access is opt-in)
merged gates = [ "system-access" "workstation-access" ]
intersection with merged gates = []

enable = false  -- json does NOT get a Unix account
```

This works because `system-access` does not include `admins` in its members.
System login is opt-in: users who need both admin and login explicitly get both
in their access bindings:

```nix
sini = [ "admins" "system-access" "wheel" ... ];  # admin + login
json = [ "admins" ];                                # admin, no login
```

## Canonical User (After Refactor)

```nix
users.sini = {
  identity = {
    displayName = "Jason Bowman";
    email = "jason@json64.dev";
    sshKeys = [ ... ];
    gpgKey = "0xE822121B6A3D7FC6";
  };
  system = {
    uid = 1000;
    gid = 1000;
    linger = true;
    extra-features = [ ];
    excluded-features = [ ];
    include-host-features = true;
  };
  # No: groups, systemGroups, enable — all derived from ACL
};
```

Identity-only users are just users with identity and no system config:

```nix
users.json = { identity.displayName = "Jason"; };
users.greco = { };
```

## Kanidm Provisioning (After Refactor)

Service files keep only OAuth2 client config (scopeMaps, claimMaps). Group
definitions move to top-level `groups`.

The Kanidm provisioner:

1. Reads kanidm-scoped `groups` to create Kanidm groups with membership rules.
1. Reads `environment.access` to create Kanidm persons for users that have any
   kanidm-scoped group in their (transitively resolved) membership.

## Fields Removed

| Field                                     | Replacement                               |                                          | ----------------------------------       |                                    |                                           |     |     |     |     |
| ----------------------------------------- | ----------------------------------------- | ---------------------------------------- | ---------------------------------------- | ---------------------------------- | ----------------------------------------- | --- | --- | --- | --- |
| ----------------------------------------- |
| ----------------------------------------  |
| ----------------------------------------  | ----------------------------------        |
| ---                                       | ---                                       | ---                                      | ---                                      |                                    | ----------------------------------------- |     |
| ----------------------------------------  |                                           |
| ----------------------------------------  | -------                                   | ---                                      | ---                                      | ---                                | ---                                       |     |     |
| ----------------------------------------- |                                           |                                          |
| ----------------------------------------  |                                           |                                          |
| ----------------------------------------  | -------                                   | ---                                      | ---                                      | ---                                | ---                                       |     |     |
| ----------------------------------------- |                                           |                                          |                                          |
| ----------------------------------------  |                                           |                                          |                                          |
| ----------------------------------------  | -------                                   | ---                                      | ---                                      | ---                                | ---                                       |     |     |
| ----------------------------------------- |                                           |                                          |                                          |                                    |
| ----------------------------------------  |                                           |                                          |                                          |                                    |
| ----------------------------------------  | -------                                   | ---                                      | ---                                      | ---                                |                                           |     |     |     |     |
| ----------------------------------------- |                                           |                                          |                                          |                                    |                                           |
| ----------------------------------------  | ----------------------------------        |
| ---                                       | ---                                       |                                          | ---------------------------------------- | -------                            | ---                                       |     |     |     |
| `users.<name>.groups`                     | `environments.<env>.access.<name>`        |                                          |                                          |                                    |                                           |     |     |     |     |
| `users.<name>.system.systemGroups`        | Derived from unix-scoped group membership |
| `users.<name>.system.enable`              | Derived from system-scoped groups ∩       |                                          |                                          |                                    |                                           |     |
| system-access-groups                      |                                           | `environments.<env>.users.<name>.enable` | Derived                                  |
|                                           |                                           |                                          | `hosts.<host>.users.<name>.enable`       | Use `system-access-groups` instead |
|                                           |                                           | Kanidm                                   |                                          | group defs in service files        | Top-level `groups`                        |

## Files to Change

### New

- `modules/flake-parts/meta/group-options.nix` — `groups` option +
  `environments.<env>.access`
- `modules/groups/*.nix` — group definitions (or single file)

### Modified

- `modules/flake-parts/meta/user-options.nix` — remove `groups`
- `modules/flake-parts/meta/host-options.nix` — add `system-access-groups` with
  role defaults
- `modules/flake-parts/meta/environment-options.nix` — add `access` option, slim
  env users
- `modules/lib/feature-module-helpers.nix` — remove `groups` from env/host user
  opts
- `modules/lib/nixos-configuration-helpers.nix` — new resolution logic
- `modules/core/users/default.nix` — derive systemGroups from resolved user
- `modules/users/*.nix` — remove `groups`
- `modules/users/identity-only.nix` — remove `groups`, keep only identity
- `modules/environments/*/users.nix` — remove `enable` overrides
- `modules/hosts/patch/host.nix` — remove user enable overrides, add
  `system-access-groups`
- `modules/services/kanidm/provision/users.nix` — read from access + groups
- `modules/services/kanidm/provision/services/*.nix` — remove group definitions
- `modules/flake-parts/expose-options.nix` — expose `groups`

## Validation Plan

### 1. Basic eval (groups exist as flake output)

```bash
nix eval .#groups --apply builtins.attrNames
# expect: [ "admins" "audio" "grafana.access" ... "workstation-access" ]
```

### 2. Access bindings exist

```bash
nix eval .#environments.prod.access --apply builtins.attrNames
# expect: [ "ellen" "greco" "hugs" "jason" "jenn" ... "sini" "shuo" "will" ... ]
```

### 3. User identity still accessible

```bash
nix eval .#users.sini.identity.displayName
# expect: "Jason Bowman"
```

### 4. Host system-access-groups defaults

```bash
nix eval .#hosts.cortex.system-access-groups
# expect: [ "workstation-access" ]  (from workstation role)

nix eval .#hosts.axon-01.system-access-groups
# expect: [ "server-access" ]  (from server role)
```

### 5. Cortex eval (full NixOS config)

```bash
nix eval .#nixosConfigurations.cortex.config.system.nixos.version
# expect: version string, no errors
```

### 6. Verify sini gets login on cortex (workstation)

```bash
nix eval .#nixosConfigurations.cortex.config.users.users --apply 'u: builtins.attrNames u'
# expect: includes "sini", "shuo" (both have workstation-access)
```

### 7. Verify identity-only users don't get Unix accounts

```bash
# json should NOT appear in system users on cortex
nix eval .#nixosConfigurations.cortex.config.users.users.json.uid or null
# expect: error (json not defined as system user)
```

### 8. Verify systemGroups derived correctly

```bash
nix eval .#nixosConfigurations.cortex.config.users.users.sini.extraGroups
# expect: [ "wheel" "podman" "libvirtd" "audio" "video" "render" ... ]
```

### 9. Verify patch only gets sini

```bash
nix eval .#darwinConfigurations.patch.config.users.users --apply 'u: builtins.attrNames u'
# expect: includes "sini", NOT "shuo" or "will"
```

### 10. Full flake check

```bash
nix flake check --no-build
# expect: only pre-existing agenix-rekey error
```

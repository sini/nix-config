# Tier 2+ Scoped Packages Design

## Problem

Tier 2+ features need context (user identity, environment config, host topology)
that doesn't exist in an isolated HM evaluation. We need a way to inject this
context and organize the outputs by scope.

## Output Structure

```
legacyPackages.<system>/
  # Tier 1: no context (flat, auto-discovered)
  alacritty
  starship
  spicetify

  # User scope: identity only
  <user>/
    gitkraken          # user.identity.{email, displayName, gpgKey}
    jujutsu            # user.identity.gpgKey

  # Environment + user scope: identity + environment config
  <env>/<user>/
    git                # user.identity + environment.email.domain (fallback)

  # Host scope: host topology (no user)
  <host>/
    gpg                # host.hasFeature("xserver"), host.isDarwin

  # Host + user scope: full resolution
  <host>/<user>/
    git                # host settings + env settings + user identity
    gpg                # host features + user (if gpg needed user context)
```

## Context Resolution

Each scope maps to existing resolution machinery:

| Scope | Context source | What's available |
|---|---|---|
| `<user>` | `config.users.<name>` | `user.identity`, canonical `user.system.settings` |
| `<env>/<user>` | `config.environments.<env>` + resolved user | + `environment.*`, env-level user settings |
| `<host>` | `config.hosts.<host>` | `host.*`, `host.hasFeature`, resolved `settings` |
| `<host>/<user>` | host + resolved user | Full resolution: host settings + env settings + user identity + per-host user settings |

## Scope Selection

The `contextRequirements` metadata determines the minimum scope:

| contextRequirements | Minimum scope | Examples |
|---|---|---|
| `["user"]` | `<user>` | gitkraken, jujutsu |
| `["user", "environment"]` | `<env>/<user>` | git |
| `["host"]` | `<host>` | gpg, waybar, hyprpanel |
| `["host", "user"]` | `<host>/<user>` | (future) |

## Context Injection

For each scope, we build an `extraSpecialArgs` attrset matching what
`prepareHostContext` and `makeHomeConfig` provide in the NixOS evaluation:

### User scope

```nix
extraSpecialArgs = {
  inherit inputs;
  user = config.users.${userName} // {
    settings = resolveFeatureSettings { ... canonical user settings ... };
  };
};
```

### Environment + user scope

```nix
extraSpecialArgs = {
  inherit inputs;
  environment = config.environments.${envName};
  user = resolvedUser // {
    settings = resolveFeatureSettings { ... canonical + env layers ... };
  };
};
```

### Host scope

```nix
extraSpecialArgs = {
  inherit inputs;
  host = config.hosts.${hostName} // {
    hasFeature = name: lib.elem name computedFeatures;
    isDarwin = lib.hasSuffix "-darwin" config.hosts.${hostName}.system;
  };
  settings = resolveFeatureSettings { ... env + host layers ... };
};
```

### Host + user scope

Same as host scope plus resolved user with full settings layers.

## Implementation Notes

- Use `legacyPackages` (not `packages`) for nesting — `packages` requires flat
  derivation attrsets per the flake schema.
- `nix run .#sini.gitkraken` resolves through `legacyPackages` automatically.
- Tier 1 packages stay in `packages` (flat) for `nix flake check` compatibility.
- The wrapper module iterates `config.users`, `config.environments`,
  `config.hosts` to generate all valid scope combinations.
- Only generate outputs for scopes that have features needing that context level.

## Non-wrappable (osConfig)

Features requiring `osConfig` (sysmon, hyprland, agenix) cannot be wrapped at
any scope — they need a live NixOS system evaluation. These are excluded
regardless of scope.

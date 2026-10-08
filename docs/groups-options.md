- `groups`: \
  Shared group definitions provisioned to Kanidm and consumed by NixOS. All
  groups are registered in Kanidm for LDAP exposure and identity management.

- `groups.<name>.description`: [string] Human-readable purpose of this group

- `groups.<name>.labels`: [list of (one of "user-role", "posix", "oauth-grant")]
  \
  Labels determine group capabilities and usage:
  - user-role: User-facing role group (identity/login gate)
  - posix: Unix group (NixOS extraGroups; Kanidm assigns its own gidNumber)
  - oauth-grant: Included in OAuth2 claims for OIDC services

- `groups.<name>.members`: [list of string] Other groups whose members are
  transitively included in this group

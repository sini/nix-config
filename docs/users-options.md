- `users`: User specifications — canonical identity, system defaults, and feature configuration

- `users.<name>.identity`: User identity information (single source of truth)

- `users.<name>.identity.displayName`: [string] Display name for the user (defaults to username)

- `users.<name>.identity.email`: [null or string] Email address for the user

- `users.<name>.identity.gpgKey`: [null or string] GPG key ID for the user (parent key ID)

- `users.<name>.identity.sshKeys`: SSH public keys for the user, each with an optional tag

- `users.<name>.identity.sshKeys.*.key`: [string] SSH public key string

- `users.<name>.identity.sshKeys.*.tag`: [null or string] Tag to categorize the SSH key (e.g., 'laptop', 'workstation', 'yubikey')

- `users.<name>.name`: [unspecified value] Username

- `users.<name>.system`: Unix account defaults and home-manager feature configuration

- `users.<name>.system.enableUnixAccount`: [boolean] Whether this user should be provisioned as a Kanidm posixAccount (enables Unix attributes in Kanidm)

- `users.<name>.system.excluded-features`: [list of string] List of feature names to exclude for this user

- `users.<name>.system.extra-features`: [list of string] List of home-manager feature names to enable for this user

- `users.<name>.system.gid`: [null or signed integer] Group ID for the Unix account (defaults to uid if not set)

- `users.<name>.system.include-host-features`: [boolean] \
  Whether to inherit all home-manager features from the host configuration.
  When true, the user receives home modules from all of the host's active features.
  When false, only user-specific extra-features (and core) are included.

- `users.<name>.system.linger`: [boolean] Enable lingering for the user (systemd user services start without login)

- `users.<name>.system.uid`: [null or signed integer] User ID for the Unix account

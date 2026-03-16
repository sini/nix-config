- `flake.users`: User specifications and configurations

- `flake.users.<name>.baseline`: Baseline features and configurations shared by all of this user's configurations

- `flake.users.<name>.baseline.features`: [list of string] \
  List of baseline features shared by all of this user's configurations.

  Note that the "core" feature
  (`users.<username>.features.core`) will _always_ be
  included in all of the user's configurations. This
  follows the same behavior as the "core" feature in
  the system scope, which is included in all system
  configurations.

- `flake.users.<name>.baseline.inheritHostFeatures`: [boolean] \
  Whether to inherit all home-manager features from the host configuration.

  When true, this user will receive all home-manager modules from the host's
  enabled features. When false, only user-specific features and baseline features
  will be included.

  This allows for more granular control over which users get which features on
  shared systems.

- `flake.users.<name>.configuration`: [module] NixOS configuration for this user

- `flake.users.<name>.features`: \
  User-specific feature definitions.

  Note that due to these features' nature as user-specific, they
  may not define NixOS modules, which would affect the entire system.

- `flake.users.<name>.features.<name>.darwin`: [module] A Darwin-specific system module for this feature (macOS only)

- `flake.users.<name>.features.<name>.excludes`: [list of string] List of names of features to exclude from this feature (prevents the feature and its requires from being added)

- `flake.users.<name>.features.<name>.home`: [module] A Home-Manager module for this feature

- `flake.users.<name>.features.<name>.linux`: [module] A Linux-specific system module for this feature (NixOS only)

- `flake.users.<name>.features.<name>.requires`: [list of string] List of names of features required by this feature

- `flake.users.<name>.features.<name>.system`: [module] A cross-platform system module for this feature (NixOS and Darwin)

- `flake.users.<name>.name`: [unspecified value] Username

- `flake.hosts`: Per-host NixOS configurations.

- `flake.hosts.<name>.baseline`: Baseline configurations for repeatable configuration types on this host

- `flake.hosts.<name>.baseline.home`: [module] Host-specific home-manager configuration, applied to all users for host.

- `flake.hosts.<name>.environment`: [string] Environment name that this host belongs to (references flake.environments)

- `flake.hosts.<name>.exclude-features`: [list of string] List of features to exclude for the host (prevents the feature and its requires from being added)

- `flake.hosts.<name>.exporters`: \
  Prometheus exporters exposed by this host.
  Example: `{ node = { port = 9100; }; k3s = { port = 10249; }; }`

- `flake.hosts.<name>.exporters.<name>.interval`: [string] Scrape interval

- `flake.hosts.<name>.exporters.<name>.path`: [string] HTTP path for metrics endpoint

- `flake.hosts.<name>.exporters.<name>.port`: [signed integer] Port number for the exporter

- `flake.hosts.<name>.extra_modules`: [list of module] List of additional modules to include for the host.

- `flake.hosts.<name>.facts`: [null or absolute path] Path to the Facter JSON file for the host.

- `flake.hosts.<name>.features`: [list of string] List of features for the host.

- `flake.hosts.<name>.hostname`: [unspecified value] Hostname

- `flake.hosts.<name>.ipv4`: [list of string] The static IP addresses of this host in its home vlan (derived from networking.interfaces)

- `flake.hosts.<name>.ipv6`: [list of string] The static IPv6 addresses of this host (derived from networking.interfaces)

- `flake.hosts.<name>.networking`: Network configuration for the host

- `flake.hosts.<name>.networking.autobridging`: [boolean] Enable automatic 1:1 bridge creation for each interface

- `flake.hosts.<name>.networking.bridges`: [attribute set of list of string] Attribute set mapping bridge names to lists of interfaces

- `flake.hosts.<name>.networking.interfaces`: Network interfaces with their IP addresses

- `flake.hosts.<name>.networking.interfaces.<name>.ipv4`: [list of string] IPv4 addresses for this interface

- `flake.hosts.<name>.networking.interfaces.<name>.ipv6`: [list of string] IPv6 addresses for this interface

- `flake.hosts.<name>.networking.unmanagedInterfaces`: [list of string] List of interfaces to mark as unmanaged by NetworkManager

- `flake.hosts.<name>.public_key`: [absolute path] Path to or string value of the public SSH key for the host.

- `flake.hosts.<name>.remoteBuildJobs`: [signed integer] The number of build jobs to be scheduled

- `flake.hosts.<name>.remoteBuildSpeed`: [signed integer] The relative build speed

- `flake.hosts.<name>.roles`: [list of string] List of roles for the host.

- `flake.hosts.<name>.system`: [one of "aarch64-linux", "x86_64-linux", "aarch64-darwin"] System string for the host

- `flake.hosts.<name>.systemConfiguration`: [module] Host-specific system module configuration.

- `flake.hosts.<name>.tags`: [attribute set of string] \
  An attribute set of string key-value pairs to tag the host with metadata.
  Example: `{ "kubernetes-cluster" = "prod"; "kubernetes-internal-ip" = "10.0.1.100"; }`

  Special tags:
  - bgp-asn: BGP AS number for this host (used by bgp-hub and thunderbolt-mesh modules)
  - thunderbolt-interface-1: IPv4 address for first thunderbolt interface (e.g., "169.254.12.0/31")
  - thunderbolt-interface-2: IPv4 address for second thunderbolt interface (e.g., "169.254.31.1/31")

- `flake.hosts.<name>.unstable`: [boolean] Whether to use nixpkgs-unstable for this host.

- `flake.hosts.<name>.users`: Users on this host with their features and configuration

- `flake.hosts.<name>.users.<name>.baseline`: Baseline features and configurations shared by all of this user's configurations

- `flake.hosts.<name>.users.<name>.baseline.features`: [list of string] List of baseline features shared by all of this user's configurations.

- `flake.hosts.<name>.users.<name>.baseline.inheritHostFeatures`: [boolean] \
  Whether to inherit all home-manager features from the host configuration.

  When true, this user will receive all home-manager modules from the host's
  enabled features. When false, only user-specific features and baseline features
  will be included.

- `flake.hosts.<name>.users.<name>.configuration`: [module] User-specific home configuration

- `flake.hosts.<name>.users.<name>.displayName`: [string] Display name for the user (defaults to username)

- `flake.hosts.<name>.users.<name>.email`: [null or string] \
  Email address for the user.
  If null, defaults to username@domain.
  If set, used as the full email address.

- `flake.hosts.<name>.users.<name>.enableUnixAccount`: [boolean] \
  Whether to create a Unix user account on hosts.
  If false, this is an identity-only user (e.g., for Kanidm).

- `flake.hosts.<name>.users.<name>.features`: [list of string] \
  List of features specific to the user.

  While a feature may specify NixOS modules in addition to home
  modules, only home modules will affect configuration. For this
  reason, users should be encouraged to avoid pointlessly specifying
  their own NixOS modules.

- `flake.hosts.<name>.users.<name>.gid`: [null or signed integer] Group ID for the Unix account (defaults to uid if not set)

- `flake.hosts.<name>.users.<name>.gpgKey`: [null or string] \
  GPG key ID for the user (parent key ID).
  Used for git commit signing, sops encryption, etc.

- `flake.hosts.<name>.users.<name>.groups`: [list of string] List of identity groups the user belongs to (defaults to ['users'])

- `flake.hosts.<name>.users.<name>.linger`: [boolean] Enable lingering for the user (systemd user services start without login)

- `flake.hosts.<name>.users.<name>.sshKeys`: [list of string] \
  SSH public keys for the user.
  Can be used by system user configuration, Forgejo, etc.

- `flake.hosts.<name>.users.<name>.systemGroups`: [list of string] \
  System groups (extraGroups) for the user.
  Example: ["wheel", "networkmanager", "podman"]

- `flake.hosts.<name>.users.<name>.uid`: [null or signed integer] User ID for the Unix account

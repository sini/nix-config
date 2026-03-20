- `hosts`: Per-host NixOS configurations.

- `hosts.<name>.baseline`: Baseline configurations for repeatable configuration types on this host

- `hosts.<name>.baseline.home`: [module] Host-specific home-manager configuration, applied to all users for host.

- `hosts.<name>.channel`: [one of "nix-darwin-unstable", "nixos-stable", "nixos-unstable", "nixpkgs-master", "nixpkgs-stable-darwin"] The nixpkgs channel to use for this host, determining nixpkgs, home-manager, and nix-darwin inputs.

- `hosts.<name>.environment`: [string] Environment name that this host belongs to (references environments)

- `hosts.<name>.excluded-features`: [list of string] List of features to exclude for the host (prevents the feature and its requires from being added)

- `hosts.<name>.exporters`: \
  Prometheus exporters exposed by this host.
  Example: `{ node = { port = 9100; }; k3s = { port = 10249; }; }`

- `hosts.<name>.exporters.<name>.interval`: [string] Scrape interval

- `hosts.<name>.exporters.<name>.path`: [string] HTTP path for metrics endpoint

- `hosts.<name>.exporters.<name>.port`: [signed integer] Port number for the exporter

- `hosts.<name>.extra-features`: [list of string] List of additional features to enable for the host (beyond those from roles).

- `hosts.<name>.extra_modules`: [list of module] List of additional modules to include for the host.

- `hosts.<name>.facts`: [null or absolute path] Path to the Facter JSON file for the host.

- `hosts.<name>.features`: [list of string] \
  Computed list of all enabled features for this host.
  Includes features from roles, extra-features, and all transitive dependencies,
  with excluded-features applied.

- `hosts.<name>.hasFeature`: [function that evaluates to a(n) boolean] \
  Helper function to check if a feature is enabled for this host.
  Returns true if the feature is in the computed features list, false otherwise.
  Example: host.hasFeature "podman" → true/false

- `hosts.<name>.hostname`: [unspecified value] Hostname

- `hosts.<name>.ipv4`: [list of string] The static IP addresses of this host in its home vlan (derived from networking.interfaces)

- `hosts.<name>.ipv6`: [list of string] The static IPv6 addresses of this host (derived from networking.interfaces)

- `hosts.<name>.isDarwin`: [boolean] \
  Helper property to check if this host is running macOS (Darwin).
  Returns true if the system is aarch64-darwin, false otherwise.
  Example: host.isDarwin → true/false

- `hosts.<name>.networking`: Network configuration for the host

- `hosts.<name>.networking.autobridging`: [boolean] Enable automatic 1:1 bridge creation for each interface

- `hosts.<name>.networking.bridges`: [attribute set of list of string] Attribute set mapping bridge names to lists of interfaces

- `hosts.<name>.networking.interfaces`: Network interfaces with their IP addresses

- `hosts.<name>.networking.interfaces.<name>.ipv4`: [list of string] IPv4 addresses for this interface

- `hosts.<name>.networking.interfaces.<name>.ipv6`: [list of string] IPv6 addresses for this interface

- `hosts.<name>.networking.unmanagedInterfaces`: [list of string] List of interfaces to mark as unmanaged by NetworkManager

- `hosts.<name>.public_key`: [absolute path] Path to or string value of the public SSH key for the host.

- `hosts.<name>.remote-deployment-user`: [string] The user to use for remote deployments

- `hosts.<name>.remoteBuildJobs`: [signed integer] The number of build jobs to be scheduled

- `hosts.<name>.remoteBuildSpeed`: [signed integer] The relative build speed

- `hosts.<name>.roles`: [list of string] List of roles for the host.

- `hosts.<name>.secretPath`: [absolute path] Path to the directory containing secret keys for the host.

- `hosts.<name>.system`: [one of "aarch64-linux", "x86_64-linux", "aarch64-darwin"] System string for the host

- `hosts.<name>.system-access-groups`: [list of string] \
  System-scoped groups that grant Unix account creation on this host.
  Merged with environment-level system-access-groups at resolution time.
  Defaults are derived from host roles (workstation → workstation-access,
  server → server-access, fallback → system-access).

- `hosts.<name>.systemConfiguration`: [module] Host-specific system module configuration.

- `hosts.<name>.tags`: [attribute set of string] \
  An attribute set of string key-value pairs to tag the host with metadata.
  Example: `{ "kubernetes-cluster" = "prod"; "kubernetes-internal-ip" = "10.0.1.100"; }`

  Special tags:
  - bgp-asn: BGP AS number for this host (used by bgp-hub and thunderbolt-mesh modules)
  - thunderbolt-interface-1: IPv4 address for first thunderbolt interface (e.g., "169.254.12.0/31")
  - thunderbolt-interface-2: IPv4 address for second thunderbolt interface (e.g., "169.254.31.1/31")

- `hosts.<name>.users`: Users on this host with their features and configuration

- `hosts.<name>.users.<name>.excluded-features`: [null or (list of string)] Excluded features override (null to inherit)

- `hosts.<name>.users.<name>.extra-features`: [null or (list of string)] Extra home-manager features override (null to inherit)

- `hosts.<name>.users.<name>.include-host-features`: [null or boolean] Whether to inherit host features (null to inherit)

- `hosts.<name>.users.<name>.linger`: [null or boolean] Enable lingering override (null to inherit)

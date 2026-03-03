- `flake.hosts`: This option has no description.
- `flake.hosts.<name>.baseline`: Baseline configurations for repeatable configuration types on this host
- `flake.hosts.<name>.baseline.home`: [module] Host-specific home-manager configuration, applied to all users for host.
- `flake.hosts.<name>.environment`: [string] Environment name that this host belongs to (references flake.environments)
- `flake.hosts.<name>.exclude-features`: [list of string] List of features to exclude for the host (prevents the feature and its requires from being added)
- `flake.hosts.<name>.exporters`: Prometheus exporters exposed by this host.
Example: `{ node = { port = 9100; }; k3s = { port = 10249; }; }`

- `flake.hosts.<name>.exporters.<name>.interval`: [string] Scrape interval
- `flake.hosts.<name>.exporters.<name>.path`: [string] HTTP path for metrics endpoint
- `flake.hosts.<name>.exporters.<name>.port`: [signed integer] Port number for the exporter
- `flake.hosts.<name>.extra_modules`: [list of module] List of additional modules to include for the host.
- `flake.hosts.<name>.facts`: [null or absolute path] Path to the Facter JSON file for the host.
- `flake.hosts.<name>.features`: [list of string] List of features for the host
- `flake.hosts.<name>.hostname`: [unspecified value] Hostname
- `flake.hosts.<name>.ipv4`: [list of string] The static IP addresses of this host in it's home vlan.
- `flake.hosts.<name>.ipv6`: [list of string] The static IPv6 addresses of this host.
- `flake.hosts.<name>.nixosConfiguration`: [module] Host-specific NixOS module configuration.
- `flake.hosts.<name>.public_key`: [absolute path] Path to or string value of the public SSH key for the host.
- `flake.hosts.<name>.remoteBuildJobs`: [signed integer] The number of build jobs to be scheduled
- `flake.hosts.<name>.remoteBuildSpeed`: [signed integer] The relative build speed
- `flake.hosts.<name>.roles`: [list of string] List of roles for the host.
- `flake.hosts.<name>.system`: [one of "aarch64-linux", "x86_64-linux"] System string for the host
- `flake.hosts.<name>.tags`: [attribute set of string] An attribute set of string key-value pairs to tag the host with metadata.
Example: `{ "kubernetes-cluster" = "prod"; "kubernetes-internal-ip" = "10.0.1.100"; }`

Special tags:
- bgp-asn: BGP AS number for this host (used by bgp-hub and thunderbolt-mesh modules)
- thunderbolt-interface-1: IPv4 address for first thunderbolt interface (e.g., "169.254.12.0/31")
- thunderbolt-interface-2: IPv4 address for second thunderbolt interface (e.g., "169.254.31.1/31")

- `flake.hosts.<name>.unstable`: [boolean] This option has no description.
- `flake.hosts.<name>.users`: Users on this host with their features and configuration
- `flake.hosts.<name>.users.<name>.configuration`: [module] User-specific home configuration
- `flake.hosts.<name>.users.<name>.features`: [list of string] List of features specific to the user.

While a feature may specify NixOS modules in addition to home
modules, only home modules will affect configuration.  For this
reason, users should be encouraged to avoid pointlessly specifying
their own NixOS modules.


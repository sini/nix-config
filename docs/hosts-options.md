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

- `hosts.<name>.extra-features`: [list of string] List of features to enable for the host (beyond the core features).

- `hosts.<name>.extra_modules`: [list of module] List of additional modules to include for the host.

- `hosts.<name>.facts`: [null or absolute path] Path to the Facter JSON file for the host.

- `hosts.<name>.features`: [list of string] \
  Computed list of all enabled features for this host.
  Includes core features, extra-features, and all transitive dependencies,
  with excluded-features applied.

- `hosts.<name>.hasFeature`: [function that evaluates to a(n) boolean] \
  Helper function to check if a feature is enabled for this host.
  Returns true if the feature is in the computed features list, false otherwise.
  Example: host.hasFeature "podman" → true/false

- `hosts.<name>.hostname`: [unspecified value] Hostname

- `hosts.<name>.ipv4`: [list of string] Management IPv4 addresses (derived from managed interfaces, CIDR stripped)

- `hosts.<name>.ipv6`: [list of string] Management IPv6 addresses (derived from managed interfaces)

- `hosts.<name>.isDarwin`: [boolean] \
  Helper property to check if this host is running macOS (Darwin).
  Returns true if the system is aarch64-darwin, false otherwise.
  Example: host.isDarwin → true/false

- `hosts.<name>.networking`: Network configuration for the host

- `hosts.<name>.networking.autobridging`: [boolean] Enable automatic 1:1 bridge creation for each interface

- `hosts.<name>.networking.bonds`: Bond devices with their member interfaces and settings

- `hosts.<name>.networking.bonds.<name>.interfaces`: [list of string] Member interfaces for this bond

- `hosts.<name>.networking.bonds.<name>.mode`: [string] Bond mode (802.3ad, balance-xor, balance-rr, etc.)

- `hosts.<name>.networking.bonds.<name>.transmitHashPolicy`: [null or string] Transmit hash policy for the bond

- `hosts.<name>.networking.bridges`: [attribute set of list of string] Attribute set mapping bridge names to lists of interfaces

- `hosts.<name>.networking.interfaces`: Network interfaces with their IP addresses and properties

- `hosts.<name>.networking.interfaces.<name>.dhcp`: [null or one of "none", "ipv4", "ipv6", "yes"] DHCP mode. null = auto (ipv6 if static ipv4, yes if no static ipv4)

- `hosts.<name>.networking.interfaces.<name>.ipv4`: [list of string] IPv4 addresses in CIDR notation (e.g., '10.9.2.1/16')

- `hosts.<name>.networking.interfaces.<name>.ipv6`: [list of string] IPv6 addresses in CIDR notation

- `hosts.<name>.networking.interfaces.<name>.linkLocal`: [null or one of "ipv4", "ipv6", "yes", "no"] Link-local addressing. null = auto (ipv6 for managed, no for unmanaged).

- `hosts.<name>.networking.interfaces.<name>.managed`: [boolean] Apply environment gateway/DNS/subnet. false for point-to-point or standalone links.

- `hosts.<name>.networking.interfaces.<name>.mtu`: [null or signed integer] MTU for this interface. null = system default.

- `hosts.<name>.networking.interfaces.<name>.requiredForOnline`: [null or string] RequiredForOnline value. null = auto (routable).

- `hosts.<name>.public_key`: [absolute path] Path to or string value of the public SSH key for the host.

- `hosts.<name>.remote-deployment-user`: [string] The user to use for remote deployments

- `hosts.<name>.remoteBuildJobs`: [signed integer] The number of build jobs to be scheduled

- `hosts.<name>.remoteBuildSpeed`: [signed integer] The relative build speed

- `hosts.<name>.secretPath`: [absolute path] Path to the directory containing secret keys for the host.

- `hosts.<name>.settings`: Per-host feature settings (overrides environment defaults)

- `hosts.<name>.settings.bgp`: Settings for the bgp feature

- `hosts.<name>.settings.bgp-hub`: Settings for the bgp-hub feature

- `hosts.<name>.settings.bgp-hub.autoDiscoverNeighbors`: [boolean] Automatically discover neighbors from flake hosts

- `hosts.<name>.settings.bgp-hub.defaultOriginateToNeighbors`: [boolean] Whether to originate default route to auto-discovered neighbors

- `hosts.<name>.settings.bgp-hub.gatewayAsNumber`: [signed integer] AS number of the gateway router

- `hosts.<name>.settings.bgp-hub.maximumPaths`: [signed integer] Maximum number of BGP paths

- `hosts.<name>.settings.bgp-hub.neighborAsNumberBase`: [signed integer] Base AS number for auto-discovered neighbors (fallback when host has no bgp.localAsn setting)

- `hosts.<name>.settings.bgp-hub.neighborDiscoveryRole`: [string] Feature name to filter hosts for auto-discovery

- `hosts.<name>.settings.bgp-hub.neighbors`: List of manually configured BGP neighbors

- `hosts.<name>.settings.bgp-hub.neighbors.*.address`: [string] Neighbor IP address

- `hosts.<name>.settings.bgp-hub.neighbors.*.asNumber`: [signed integer] Neighbor AS number

- `hosts.<name>.settings.bgp-hub.neighbors.*.defaultOriginate`: [boolean] Whether to originate default route to this neighbor

- `hosts.<name>.settings.bgp-hub.peerWithGateway`: [boolean] Whether to automatically peer with the environment gateway (Unifi router)

- `hosts.<name>.settings.bgp.localAsn`: [signed integer] Local BGP AS number for this node

- `hosts.<name>.settings.btrfs-impermanence-single`: Settings for the btrfs-impermanence-single feature

- `hosts.<name>.settings.btrfs-impermanence-single.device_id`: [string] \
  Disk device id (e.g., "ata-..." or "/dev/disk/by-id/...").
  If not set, the module attempts to find a single non-USB disk
  via facter. Aborts if multiple or no disks are found.

- `hosts.<name>.settings.btrfs-impermanence-single.swap_size`: [signed integer] Size of swap in MiB, 0 disables swap.

- `hosts.<name>.settings.ceph-device-allocation`: Settings for the ceph-device-allocation feature

- `hosts.<name>.settings.ceph-device-allocation.device`: [string] Full device path for Ceph OSD (e.g., /dev/disk/by-id/nvme-...).

- `hosts.<name>.settings.cilium-bgp`: Settings for the cilium-bgp feature

- `hosts.<name>.settings.cilium-bgp.localAsn`: [signed integer] Cilium BGP AS number for this node

- `hosts.<name>.settings.impermanence`: Settings for the impermanence feature

- `hosts.<name>.settings.impermanence.enable`: [boolean] Enable impermanence features.

- `hosts.<name>.settings.impermanence.wipeHomeOnBoot`: [boolean] \
  Enable home rollback on boot. When enabled, /home is reset to a
  blank snapshot on every boot. Use with caution - ensure all
  important user data is declared in persistence directories.

- `hosts.<name>.settings.impermanence.wipeRootOnBoot`: [boolean] \
  Enable root rollback on boot. When enabled, the root filesystem
  is reset to a blank snapshot on every boot, effectively wiping
  all state not stored in /persist or /cache.

- `hosts.<name>.settings.linux-kernel`: Settings for the linux-kernel feature

- `hosts.<name>.settings.linux-kernel.channel`: [one of "lts", "latest"] CachyOS kernel release channel

- `hosts.<name>.settings.linux-kernel.optimization`: [one of "server", "zen4", "x86_64-v4"] CachyOS kernel optimization target

- `hosts.<name>.settings.tailscale`: Settings for the tailscale feature

- `hosts.<name>.settings.tailscale.extraDaemonFlags`: [list of string] Additional flags for the tailscale daemon

- `hosts.<name>.settings.tailscale.extraUpFlags`: [list of string] Additional flags to pass to tailscale up (login-server is added automatically)

- `hosts.<name>.settings.tailscale.openFirewall`: [boolean] Whether to open the firewall for Tailscale

- `hosts.<name>.settings.tailscale.useNftables`: [boolean] Force tailscaled to use nftables instead of iptables-compat

- `hosts.<name>.settings.thunderbolt-mesh-of`: Settings for the thunderbolt-mesh-of feature

- `hosts.<name>.settings.thunderbolt-mesh-of.interfaces`: [list of string] Thunderbolt interface names to enable OpenFabric on (tb0, tb1, ... from thunderbolt hardware feature)

- `hosts.<name>.settings.thunderbolt-mesh-of.loopback`: Loopback addresses for this node in the OpenFabric fabric

- `hosts.<name>.settings.thunderbolt-mesh-of.loopback.ipv4`: [string] IPv4 loopback address in CIDR (e.g., '172.16.255.1/32')

- `hosts.<name>.settings.thunderbolt-mesh-of.loopback.ipv6`: [null or string] IPv6 loopback address in CIDR (e.g., 'fdb4:5edb:1b00::1/128')

- `hosts.<name>.settings.thunderbolt-mesh-of.nsap`: [string] ISO NSAP address for this node (e.g., '49.0000.0000.0001.00')

- `hosts.<name>.settings.xfs-disk-longhorn`: Settings for the xfs-disk-longhorn feature

- `hosts.<name>.settings.xfs-disk-longhorn.device_id`: [string] Longhorn data drive full device path (e.g., /dev/disk/by-id/nvme-...).

- `hosts.<name>.settings.xfs-disk-longhorn.mountPoint`: [string] Mount point for the Longhorn data drive.

- `hosts.<name>.settings.zfs-disk-single`: Settings for the zfs-disk-single feature

- `hosts.<name>.settings.zfs-disk-single.device_id`: [string] \
  Disk device path (e.g., "/dev/disk/by-id/nvme-...").
  If not set, the module attempts to find a single non-USB disk
  via facter. Aborts if multiple or no disks are found.

- `hosts.<name>.system`: [one of "aarch64-linux", "x86_64-linux", "aarch64-darwin"] System string for the host

- `hosts.<name>.system-access-groups`: [list of string] \
  System-scoped groups that grant Unix account creation on this host.
  Merged with environment-level system-access-groups at resolution time.
  Defaults are derived from host roles (workstation → workstation-access,
  server → server-access, fallback → system-access).

- `hosts.<name>.system-owner`: [null or string] \
  The primary user who owns this host. Used by features that require
  a single user (e.g. libvirt QEMU process owner, sunshine game streaming).
  When null, defaults to the first canonical user with system-access scope.

- `hosts.<name>.systemConfiguration`: [module] Host-specific system module configuration.

- `hosts.<name>.users`: Users on this host with their features and configuration

- `hosts.<name>.users.<name>.excluded-features`: [null or (list of string)] Excluded features override (null to inherit)

- `hosts.<name>.users.<name>.extra-features`: [null or (list of string)] Extra home-manager features override (null to inherit)

- `hosts.<name>.users.<name>.include-host-features`: [null or boolean] Whether to inherit host features (null to inherit)

- `hosts.<name>.users.<name>.linger`: [null or boolean] Enable lingering override (null to inherit)

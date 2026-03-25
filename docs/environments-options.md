- `environments`: Environment configurations

- `environments.<name>.access`: [attribute set of list of string] \
  Maps usernames to lists of group names for this environment.
  Groups can be from any scope (kanidm, unix, system).
  A user appearing here with kanidm-scoped groups is provisioned as a Kanidm person.
  A user with system-scoped groups matching a host's system-access-groups gets a Unix account.
  A user with unix-scoped groups gets those as extraGroups on their Unix account.

- `environments.<name>.acme`: ACME certificate authority configuration

- `environments.<name>.acme.dnsProvider`: [string] DNS provider for ACME challenges

- `environments.<name>.acme.dnsResolver`: [string] DNS resolver for ACME validation

- `environments.<name>.acme.server`: [string] ACME server URL

- `environments.<name>.certificates`: Certificate management configuration for the environment

- `environments.<name>.certificates.domains`: Domains to generate certificates for (typically wildcard certs)

- `environments.<name>.certificates.domains.<name>.issuer`: [string] The issuer name to use for this domain

- `environments.<name>.certificates.issuers`: Certificate issuer configurations (e.g., ACME DNS API credentials)

- `environments.<name>.certificates.issuers.<name>.ageKeyFile`: [null or absolute path] Optional path to the file containing the API key (agenix)

- `environments.<name>.delegation`: Cross-environment delegation configuration

- `environments.<name>.delegation.authTo`: [null or string] Environment to delegate authentication to (e.g., 'prod')

- `environments.<name>.delegation.logsTo`: [null or string] Environment to delegate log shipping to (e.g., 'prod')

- `environments.<name>.delegation.metricsTo`: [null or string] Environment to delegate metrics reporting to (e.g., 'prod')

- `environments.<name>.domain`: [string] Base domain for the environment

- `environments.<name>.domainToResourceName`: [function that evaluates to a(n) string] \
  Helper function to convert a domain to a Kubernetes resource name.
  Takes the last 2 parts of the domain (e.g., "json64-dev" from "argocd.prod.json64.dev").

- `environments.<name>.email`: Email configuration for the environment

- `environments.<name>.email.adminEmail`: [string] Default admin email address

- `environments.<name>.email.domain`: [string] Email domain (e.g., json64.dev)

- `environments.<name>.findHostsByFeature`: [function that evaluates to a(n) attribute set of unspecified value] \
  Helper function to find all hosts in this environment that have a specific feature.
  Returns an attrset of hosts filtered by the specified feature.

- `environments.<name>.getAssignment`: [function that evaluates to a(n) (null or string)] \
  Helper function to get an IP assignment by name across all networks.
  Returns the IP address if found, null otherwise.
  Example: getAssignment "kube-apiserver-vip" → "10.9.0.100"

- `environments.<name>.getDomainFor`: [function that evaluates to a(n) string] \
  Helper function to get the domain for a service.
  Returns the configured service domain or defaults to \<service-name>.\<environment.domain>

- `environments.<name>.getTopDomainFor`: [function that evaluates to a(n) string] \
  Helper function to get the top-level domain for a service.
  Returns the last 2 parts of the service domain as a string (e.g., "json64.dev" from "argocd.prod.json64.dev").

- `environments.<name>.id`: [signed integer] ID of the environment

- `environments.<name>.location`: Geographic location information

- `environments.<name>.location.country`: [string] ISO country code

- `environments.<name>.location.region`: [string] Geographic region or datacenter

- `environments.<name>.monitoring`: Monitoring configuration including cross-environment scanning

- `environments.<name>.monitoring.scanEnvironments`: [list of string] Additional environments to scan for metrics (e.g., ['dev'] for prod scanning dev)

- `environments.<name>.name`: [string] Human-readable environment name

- `environments.<name>.networks`: \
  Network definitions for the environment.
  Network names should match their purpose (e.g., default, kubernetes-pods, kubernetes-services).
  Example:

  ```nix
  {
    default = { cidr = "10.0.0.0/24"; };
    kubernetes-pods = { cidr = "172.20.0.0/16"; };
  }
  ```

- `environments.<name>.networks.<name>.assignments`: [attribute set of string] \
  Static IP address assignments within this network.
  Maps service/resource names to their assigned IP addresses.
  Example: { kube-apiserver-vip = "10.9.0.100"; }

- `environments.<name>.networks.<name>.cidr`: [string] Network CIDR (e.g., 10.0.0.0/24)

- `environments.<name>.networks.<name>.description`: [string] Human-readable description of the network

- `environments.<name>.networks.<name>.dnsServers`: [list of string] DNS server IPs for this network

- `environments.<name>.networks.<name>.gatewayIp`: [null or string] Gateway IP address for this network

- `environments.<name>.networks.<name>.gatewayIpV6`: [null or string] Gateway IPv6 address for this network

- `environments.<name>.networks.<name>.ipv6_cidr`: [null or string] IPv6 network CIDR (e.g., fd64:0:1::/64)

- `environments.<name>.networks.<name>.wireless`: Wireless network configuration (typically used for 'default' network)

- `environments.<name>.networks.<name>.wireless.pskRef`: [string] PSK reference for the wireless network (e.g., ext:psk_arcade)

- `environments.<name>.networks.<name>.wireless.ssid`: [string] SSID of the wireless network

- `environments.<name>.secretPath`: [absolute path] Path to the directory containing secrets for the environment.

- `environments.<name>.services`: \
  Service-specific domain mappings for the environment.
  Used by OAuth2 provisioning, ingress configuration, and service discovery.
  Example: services.argocd.domain = "argocd.zeroday.run";

- `environments.<name>.services.<name>.delegateTo`: [null or string] \
  Name of another environment to delegate this service to.
  When set, the service is considered to be hosted by the specified environment.

- `environments.<name>.services.<name>.domain`: [null or string] \
  Override domain for this service.
  If null, defaults to \<service-name>.${environment.domain}

- `environments.<name>.settings`: Default feature settings for all hosts in this environment

- `environments.<name>.settings.bgp`: Settings for the bgp feature

- `environments.<name>.settings.bgp-hub`: Settings for the bgp-hub feature

- `environments.<name>.settings.bgp-hub.autoDiscoverNeighbors`: [boolean] Automatically discover neighbors from flake hosts

- `environments.<name>.settings.bgp-hub.defaultOriginateToNeighbors`: [boolean] Whether to originate default route to auto-discovered neighbors

- `environments.<name>.settings.bgp-hub.gatewayAsNumber`: [signed integer] AS number of the gateway router

- `environments.<name>.settings.bgp-hub.maximumPaths`: [signed integer] Maximum number of BGP paths

- `environments.<name>.settings.bgp-hub.neighborAsNumberBase`: [signed integer] Base AS number for auto-discovered neighbors (fallback when host has no bgp.localAsn setting)

- `environments.<name>.settings.bgp-hub.neighborDiscoveryRole`: [string] Feature name to filter hosts for auto-discovery

- `environments.<name>.settings.bgp-hub.neighbors`: List of manually configured BGP neighbors

- `environments.<name>.settings.bgp-hub.neighbors.*.address`: [string] Neighbor IP address

- `environments.<name>.settings.bgp-hub.neighbors.*.asNumber`: [signed integer] Neighbor AS number

- `environments.<name>.settings.bgp-hub.neighbors.*.defaultOriginate`: [boolean] Whether to originate default route to this neighbor

- `environments.<name>.settings.bgp-hub.peerWithGateway`: [boolean] Whether to automatically peer with the environment gateway (Unifi router)

- `environments.<name>.settings.bgp.localAsn`: [signed integer] Local BGP AS number for this node

- `environments.<name>.settings.btrfs-impermanence-single`: Settings for the btrfs-impermanence-single feature

- `environments.<name>.settings.btrfs-impermanence-single.device_id`: [string] \
  Disk device id (e.g., "ata-..." or "/dev/disk/by-id/...").
  If not set, the module attempts to find a single non-USB disk
  via facter. Aborts if multiple or no disks are found.

- `environments.<name>.settings.btrfs-impermanence-single.swap_size`: [signed integer] Size of swap in MiB, 0 disables swap.

- `environments.<name>.settings.ceph-device-allocation`: Settings for the ceph-device-allocation feature

- `environments.<name>.settings.ceph-device-allocation.device`: [string] Full device path for Ceph OSD (e.g., /dev/disk/by-id/nvme-...).

- `environments.<name>.settings.cilium-bgp`: Settings for the cilium-bgp feature

- `environments.<name>.settings.cilium-bgp.localAsn`: [signed integer] Cilium BGP AS number for this node

- `environments.<name>.settings.impermanence`: Settings for the impermanence feature

- `environments.<name>.settings.impermanence.enable`: [boolean] Enable impermanence features.

- `environments.<name>.settings.impermanence.wipeHomeOnBoot`: [boolean] \
  Enable home rollback on boot. When enabled, /home is reset to a
  blank snapshot on every boot. Use with caution - ensure all
  important user data is declared in persistence directories.

- `environments.<name>.settings.impermanence.wipeRootOnBoot`: [boolean] \
  Enable root rollback on boot. When enabled, the root filesystem
  is reset to a blank snapshot on every boot, effectively wiping
  all state not stored in /persist or /cache.

- `environments.<name>.settings.linux-kernel`: Settings for the linux-kernel feature

- `environments.<name>.settings.linux-kernel.channel`: [one of "lts", "latest"] CachyOS kernel release channel

- `environments.<name>.settings.linux-kernel.optimization`: [one of "server", "zen4", "x86_64-v4"] CachyOS kernel optimization target

- `environments.<name>.settings.tailscale`: Settings for the tailscale feature

- `environments.<name>.settings.tailscale.extraDaemonFlags`: [list of string] Additional flags for the tailscale daemon

- `environments.<name>.settings.tailscale.extraUpFlags`: [list of string] Additional flags to pass to tailscale up (login-server is added automatically)

- `environments.<name>.settings.tailscale.openFirewall`: [boolean] Whether to open the firewall for Tailscale

- `environments.<name>.settings.tailscale.useNftables`: [boolean] Force tailscaled to use nftables instead of iptables-compat

- `environments.<name>.settings.thunderbolt-mesh-of`: Settings for the thunderbolt-mesh-of feature

- `environments.<name>.settings.thunderbolt-mesh-of.interfaces`: [list of string] Thunderbolt interface names to enable OpenFabric on (tb0, tb1, ... from thunderbolt hardware feature)

- `environments.<name>.settings.thunderbolt-mesh-of.loopback`: Loopback addresses for this node in the OpenFabric fabric

- `environments.<name>.settings.thunderbolt-mesh-of.loopback.ipv4`: [string] IPv4 loopback address in CIDR (e.g., '172.16.255.1/32')

- `environments.<name>.settings.thunderbolt-mesh-of.loopback.ipv6`: [null or string] IPv6 loopback address in CIDR (e.g., 'fdb4:5edb:1b00::1/128')

- `environments.<name>.settings.thunderbolt-mesh-of.nsap`: [string] ISO NSAP address for this node (e.g., '49.0000.0000.0001.00')

- `environments.<name>.settings.xfs-disk-longhorn`: Settings for the xfs-disk-longhorn feature

- `environments.<name>.settings.xfs-disk-longhorn.device_id`: [string] Longhorn data drive full device path (e.g., /dev/disk/by-id/nvme-...).

- `environments.<name>.settings.xfs-disk-longhorn.mountPoint`: [string] Mount point for the Longhorn data drive.

- `environments.<name>.settings.zfs-disk-single`: Settings for the zfs-disk-single feature

- `environments.<name>.settings.zfs-disk-single.device_id`: [string] \
  Disk device path (e.g., "/dev/disk/by-id/nvme-...").
  If not set, the module attempts to find a single non-USB disk
  via facter. Aborts if multiple or no disks are found.

- `environments.<name>.system-access-groups`: [list of string] \
  System-scoped groups that grant Unix account creation on all hosts in this environment.
  Merged with host-level system-access-groups at resolution time.

- `environments.<name>.tags`: [attribute set of string] Environment-wide tags for metadata and organization

- `environments.<name>.timezone`: [string] Default timezone for the environment

- `environments.<name>.users`: \
  Users in this environment with their behavior overrides.
  Identity is derived from canonical users.<name>.identity.

- `environments.<name>.users.<name>.excluded-features`: [null or (list of string)] Excluded features override (null inherits from users.<name>.system)

- `environments.<name>.users.<name>.extra-features`: [null or (list of string)] Extra home-manager features override (null inherits from users.<name>.system)

- `environments.<name>.users.<name>.identity`: Identity information (derived from canonical users.<name>.identity)

- `environments.<name>.users.<name>.identity.displayName`: [string] Display name for the user (defaults to username)

- `environments.<name>.users.<name>.identity.email`: [null or string] Email address for the user

- `environments.<name>.users.<name>.identity.gpgKey`: [null or string] GPG key ID for the user (parent key ID)

- `environments.<name>.users.<name>.identity.sshKeys`: SSH public keys for the user, each with an optional tag

- `environments.<name>.users.<name>.identity.sshKeys.*.key`: [string] SSH public key string

- `environments.<name>.users.<name>.identity.sshKeys.*.tag`: [null or string] Tag to categorize the SSH key (e.g., 'laptop', 'workstation', 'yubikey')

- `environments.<name>.users.<name>.include-host-features`: [null or boolean] Whether to inherit host features (null inherits from users.<name>.system)

- `environments.<name>.users.<name>.linger`: [null or boolean] Enable lingering override (null inherits from users.<name>.system)

- `environments.<name>.wirelessSecretsFile`: [absolute path] Path to the WPA supplicant secrets file (agenix)

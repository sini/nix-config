- `environments`: Environment configurations

- `environments.<name>.access`: [attribute set of list of string] \
  Maps usernames to lists of group names for this environment. Groups can be
  from any scope (kanidm, unix, system). A user appearing here with
  kanidm-scoped groups is provisioned as a Kanidm person. A user with
  system-scoped groups matching a host's allow-logins-by gets a Unix account. A
  user with unix-scoped groups gets those as extraGroups on their Unix account.

- `environments.<name>.acme`: ACME certificate authority configuration

- `environments.<name>.acme.dnsProvider`: [string] DNS provider for ACME
  challenges

- `environments.<name>.acme.dnsResolver`: [string] DNS resolver for ACME
  validation

- `environments.<name>.acme.server`: [string] ACME server URL

- `environments.<name>.certificates`: Certificate management configuration for
  the environment

- `environments.<name>.certificates.domains`: Domains to generate certificates
  for (typically wildcard certs)

- `environments.<name>.certificates.domains.<name>.issuer`: [string] The issuer
  name to use for this domain

- `environments.<name>.certificates.issuers`: Certificate issuer configurations
  (e.g., ACME DNS API credentials)

- `environments.<name>.certificates.issuers.<name>.ageKeyFile`: \[null or
  absolute path\] Optional path to the file containing the API key (agenix)

- `environments.<name>.delegation`: Cross-environment delegation configuration

- `environments.<name>.delegation.authTo`: [null or string] Environment to
  delegate authentication to (e.g., 'prod')

- `environments.<name>.delegation.logsTo`: [null or string] Environment to
  delegate log shipping to (e.g., 'prod')

- `environments.<name>.delegation.metricsTo`: [null or string] Environment to
  delegate metrics reporting to (e.g., 'prod')

- `environments.<name>.domain`: [string] Base domain for the environment

- `environments.<name>.domainToResourceName`: \[function that evaluates to a(n)
  string\] \
  Helper function to convert a domain to a Kubernetes resource name. Takes the
  last 2 parts of the domain (e.g., "json64-dev" from "argocd.prod.json64.dev").

- `environments.<name>.email`: Email configuration for the environment

- `environments.<name>.email.adminEmail`: [string] Default admin email address

- `environments.<name>.email.domain`: [string] Email domain (e.g., json64.dev)

- `environments.<name>.findHostsByRole`: \[function that evaluates to a(n)
  attribute set of unspecified value\] \
  Helper function to find all hosts in this environment that have a specific
  role. Returns an attrset of hosts filtered by the specified role.

- `environments.<name>.getAssignment`: \[function that evaluates to a(n) (null
  or string)\] \
  Helper function to get an IP assignment by name across all networks. Returns
  the IP address if found, null otherwise. Example: getAssignment
  "kube-apiserver-vip" → "10.9.0.100"

- `environments.<name>.getDomainFor`: [function that evaluates to a(n) string] \
  Helper function to get the domain for a service. Returns the configured
  service domain or defaults to \<service-name>.\<environment.domain>

- `environments.<name>.getTopDomainFor`: \[function that evaluates to a(n)
  string\] \
  Helper function to get the top-level domain for a service. Returns the last 2
  parts of the service domain as a string (e.g., "json64.dev" from
  "argocd.prod.json64.dev").

- `environments.<name>.groups`: \[function that evaluates to a(n) attribute set
  of unspecified value\] \
  Filter shared group definitions by scope. Example: environment.groups "kanidm"
  returns all kanidm-scoped groups. Pass null to get all groups.

- `environments.<name>.id`: [signed integer] ID of the environment

- `environments.<name>.ipv6`: IPv6 ULA and prefix configuration for NPTv6
  translation

- `environments.<name>.ipv6.external_prefix`: [null or string] External ISP
  prefix for NPTv6 translation (e.g., 2001:db8::/64)

- `environments.<name>.ipv6.kubernetes_prefix`: [null or string] IPv6 prefix for
  Kubernetes pods (e.g., fd64:0:2::/64)

- `environments.<name>.ipv6.management_prefix`: [null or string] IPv6 prefix for
  management network (e.g., fd64:0:1::/64)

- `environments.<name>.ipv6.services_prefix`: [null or string] IPv6 prefix for
  Kubernetes services (e.g., fd64:0:3::/64)

- `environments.<name>.ipv6.ula_prefix`: [null or string] ULA prefix for the
  environment (e.g., fd64::/48)

- `environments.<name>.kubernetes`: Kubernetes-specific network configuration

- `environments.<name>.kubernetes.services`: \
  Kubernetes service management for this environment. Use 'enabled' to enable
  services and 'config' for service-specific options.

- `environments.<name>.kubernetes.services.config`: \
  Service-specific configurations for this environment. Options are imported
  from kubernetes.services.\<name>.options.

- `environments.<name>.kubernetes.services.config.amd-gpu-device-plugin`:
  [attribute set] Configuration for amd-gpu-device-plugin service

- `environments.<name>.kubernetes.services.config.argocd`: [attribute set]
  Configuration for argocd service

- `environments.<name>.kubernetes.services.config.bootstrap`: [attribute set]
  Configuration for bootstrap service

- `environments.<name>.kubernetes.services.config.cert-manager`: [attribute set]
  Configuration for cert-manager service

- `environments.<name>.kubernetes.services.config.cilium`: Configuration for
  cilium service

- `environments.<name>.kubernetes.services.config.cilium-bgp`: [attribute set]
  Configuration for cilium-bgp service

- `environments.<name>.kubernetes.services.config.cilium.devices`: \[null or
  (list of string)\] List of devices

- `environments.<name>.kubernetes.services.config.cilium.directRoutingDevice`:
  [null or string] Default routing device

- `environments.<name>.kubernetes.services.config.coredns`: [attribute set]
  Configuration for coredns service

- `environments.<name>.kubernetes.services.config.csi-driver-nfs`: Configuration
  for csi-driver-nfs service

- `environments.<name>.kubernetes.services.config.csi-driver-nfs.volumes`: NFS
  volumes to create storage classes for

- `environments.<name>.kubernetes.services.config.csi-driver-nfs.volumes.<name>.server`:
  [string] NFS server address

- `environments.<name>.kubernetes.services.config.csi-driver-nfs.volumes.<name>.share`:
  [string] NFS share path

- `environments.<name>.kubernetes.services.config.envoy-gateway`: \[attribute
  set\] Configuration for envoy-gateway service

- `environments.<name>.kubernetes.services.config.gateway-api`: [attribute set]
  Configuration for gateway-api service

- `environments.<name>.kubernetes.services.config.hubble-ui`: [attribute set]
  Configuration for hubble-ui service

- `environments.<name>.kubernetes.services.config.longhorn`: [attribute set]
  Configuration for longhorn service

- `environments.<name>.kubernetes.services.config.romm`: [attribute set]
  Configuration for romm service

- `environments.<name>.kubernetes.services.config.rook-ceph`: [attribute set]
  Configuration for rook-ceph service

- `environments.<name>.kubernetes.services.config.sops-secrets-operator`:
  Configuration for sops-secrets-operator service

- `environments.<name>.kubernetes.services.config.sops-secrets-operator.replicaCount`:
  [signed integer] Number of replicas for the sops-secrets-operator

- `environments.<name>.kubernetes.services.config.volume-snapshots`: \[attribute
  set\] Configuration for volume-snapshots service

- `environments.<name>.kubernetes.services.enabled`: [list of string] \
  List of enabled services for this environment. Services without configuration
  can be enabled by simply adding them to this list.

- `environments.<name>.kubernetes.sso`: Single Sign-On configuration

- `environments.<name>.kubernetes.sso.credentialsEnvironment`: [null or string]
  Environment variable name containing SSO credentials

- `environments.<name>.kubernetes.sso.issuerPattern`: [null or string] \
  SSO issuer URL pattern for authentication. Use {clientID} as a placeholder for
  the client ID. Example: "https://idm.example.com/oauth2/openid/{clientID}"

- `environments.<name>.kubernetes.tlsSanIps`: [list of string] Additional IPs to
  include in Kubernetes API server TLS certificate SANs

- `environments.<name>.location`: Geographic location information

- `environments.<name>.location.country`: [string] ISO country code

- `environments.<name>.location.region`: [string] Geographic region or
  datacenter

- `environments.<name>.monitoring`: Monitoring configuration including
  cross-environment scanning

- `environments.<name>.monitoring.scanEnvironments`: [list of string] Additional
  environments to scan for metrics (e.g., ['dev'] for prod scanning dev)

- `environments.<name>.name`: [string] Human-readable environment name

- `environments.<name>.networks`: \
  Network definitions for the environment. Network names should match their
  purpose (e.g., default, kubernetes-pods, kubernetes-services). Example:

  ```nix
  {
    default = { cidr = "10.0.0.0/24"; };
    kubernetes-pods = { cidr = "172.20.0.0/16"; };
  }
  ```

- `environments.<name>.networks.<name>.assignments`: [attribute set of string] \
  Static IP address assignments within this network. Maps service/resource names
  to their assigned IP addresses. Example: { kube-apiserver-vip = "10.9.0.100";
  }

- `environments.<name>.networks.<name>.cidr`: [string] Network CIDR (e.g.,
  10.0.0.0/24)

- `environments.<name>.networks.<name>.description`: [string] Human-readable
  description of the network

- `environments.<name>.networks.<name>.dnsServers`: [list of string] DNS server
  IPs for this network

- `environments.<name>.networks.<name>.gatewayIp`: [null or string] Gateway IP
  address for this network

- `environments.<name>.networks.<name>.gatewayIpV6`: [null or string] Gateway
  IPv6 address for this network

- `environments.<name>.networks.<name>.ipv6_cidr`: [null or string] IPv6 network
  CIDR (e.g., fd64:0:1::/64)

- `environments.<name>.secretPath`: [absolute path] Path to the directory
  containing secrets for the environment.

- `environments.<name>.secrets`: [unspecified value] \
  Secret helper functions for this environment. Provides: from, for,
  forInlineFor, forOidcService, oidcIssuerFor

- `environments.<name>.services`: \
  Service-specific domain mappings for the environment. Used by OAuth2
  provisioning, ingress configuration, and service discovery. Example:
  services.argocd.domain = "argocd.zeroday.run";

- `environments.<name>.services.<name>.delegateTo`: [null or string] \
  Name of another environment to delegate this service to. When set, the service
  is considered to be hosted by the specified environment.

- `environments.<name>.services.<name>.domain`: [null or string] \
  Override domain for this service. If null, defaults to
  \<service-name>.${environment.domain}

- `environments.<name>.tags`: [attribute set of string] Environment-wide tags
  for metadata and organization

- `environments.<name>.timezone`: [string] Default timezone for the environment

- `environments.<name>.users`: \
  Users in this environment with their behavior overrides. Identity is derived
  from canonical users.<name>.identity.

- `environments.<name>.users.<name>.excluded-features`: \[null or (list of
  string)\] Excluded features override (null inherits from users.<name>.system)

- `environments.<name>.users.<name>.extra-features`: [null or (list of string)]
  Extra home-manager features override (null inherits from users.<name>.system)

- `environments.<name>.users.<name>.identity`: Identity information (derived
  from canonical users.<name>.identity)

- `environments.<name>.users.<name>.identity.displayName`: [string] Display name
  for the user (defaults to username)

- `environments.<name>.users.<name>.identity.email`: [null or string] Email
  address for the user

- `environments.<name>.users.<name>.identity.gpgKey`: [null or string] GPG key
  ID for the user (parent key ID)

- `environments.<name>.users.<name>.identity.sshKeys`: [list of string] SSH
  public keys for the user

- `environments.<name>.users.<name>.include-host-features`: [null or boolean]
  Whether to inherit host features (null inherits from users.<name>.system)

- `environments.<name>.users.<name>.linger`: [null or boolean] Enable lingering
  override (null inherits from users.<name>.system)

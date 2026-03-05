* `flake.environments`: Environment configurations
* `flake.environments.<name>.acme`: ACME certificate authority configuration
* `flake.environments.<name>.acme.dnsProvider`: [string] DNS provider for ACME challenges
* `flake.environments.<name>.acme.dnsResolver`: [string] DNS resolver for ACME validation
* `flake.environments.<name>.acme.server`: [string] ACME server URL
* `flake.environments.<name>.certificates`: Certificate management configuration for the environment
* `flake.environments.<name>.certificates.domains`: Domains to generate certificates for (typically wildcard certs)
* `flake.environments.<name>.certificates.domains.<name>.issuer`: [string] The issuer name to use for this domain
* `flake.environments.<name>.certificates.issuers`: Certificate issuer configurations (e.g., ACME DNS API credentials)
* `flake.environments.<name>.certificates.issuers.<name>.ageKeyFile`: [null or absolute path] Optional path to the file containing the API key (agenix)
* `flake.environments.<name>.certificates.issuers.<name>.secretKey`: [null or string] The secret key name within the secrets file
* `flake.environments.<name>.certificates.issuers.<name>.sopsFile`: [null or absolute path] Optional path to the SOPS file containing the API key
* `flake.environments.<name>.delegation`: Cross-environment delegation configuration
* `flake.environments.<name>.delegation.authTo`: [null or string] Environment to delegate authentication to (e.g., 'prod')
* `flake.environments.<name>.delegation.logsTo`: [null or string] Environment to delegate log shipping to (e.g., 'prod')
* `flake.environments.<name>.delegation.metricsTo`: [null or string] Environment to delegate metrics reporting to (e.g., 'prod')
* `flake.environments.<name>.dnsServers`: [list of string] DNS server IPs for the environment
* `flake.environments.<name>.domain`: [string] Base domain for the environment
* `flake.environments.<name>.domainToResourceName`: [function that evaluates to a(n) string] \
  Helper function to convert a domain to a Kubernetes resource name.
  Takes the last 2 parts of the domain (e.g., "json64-dev" from "argocd.prod.json64.dev").
  
* `flake.environments.<name>.email`: Email configuration for the environment
* `flake.environments.<name>.email.adminEmail`: [string] Default admin email address
* `flake.environments.<name>.email.domain`: [string] Email domain (e.g., json64.dev)
* `flake.environments.<name>.findHostsByRole`: [function that evaluates to a(n) attribute set of unspecified value] \
  Helper function to find all hosts in this environment that have a specific role.
  Returns an attrset of hosts filtered by the specified role.
  
* `flake.environments.<name>.gatewayIp`: [string] Gateway IP address for the environment
* `flake.environments.<name>.gatewayIpV6`: [string] Gateway IPv6 address for the environment
* `flake.environments.<name>.getAssignment`: [function that evaluates to a(n) (null or string)] \
  Helper function to get an IP assignment by name across all networks.
  Returns the IP address if found, null otherwise.
  Example: getAssignment "kube-apiserver-vip" → "10.9.0.100"
  
* `flake.environments.<name>.getDomainFor`: [function that evaluates to a(n) string] \
  Helper function to get the domain for a service.
  Returns the configured service domain or defaults to <service-name>.<environment.domain>
  
* `flake.environments.<name>.getTopDomainFor`: [function that evaluates to a(n) string] \
  Helper function to get the top-level domain for a service.
  Returns the last 2 parts of the service domain as a string (e.g., "json64.dev" from "argocd.prod.json64.dev").
  
* `flake.environments.<name>.id`: [signed integer] ID of the environment
* `flake.environments.<name>.ipv6`: IPv6 ULA and prefix configuration for NPTv6 translation
* `flake.environments.<name>.ipv6.external_prefix`: [null or string] External ISP prefix for NPTv6 translation (e.g., 2001:db8::/64)
* `flake.environments.<name>.ipv6.kubernetes_prefix`: [null or string] IPv6 prefix for Kubernetes pods (e.g., fd64:0:2::/64)
* `flake.environments.<name>.ipv6.management_prefix`: [null or string] IPv6 prefix for management network (e.g., fd64:0:1::/64)
* `flake.environments.<name>.ipv6.services_prefix`: [null or string] IPv6 prefix for Kubernetes services (e.g., fd64:0:3::/64)
* `flake.environments.<name>.ipv6.ula_prefix`: [null or string] ULA prefix for the environment (e.g., fd64::/48)
* `flake.environments.<name>.kubernetes`: Kubernetes-specific network configuration
* `flake.environments.<name>.kubernetes.secretsFile`: [null or absolute path] Path to sops encrypted secret file for kubernetes environment
* `flake.environments.<name>.kubernetes.services`: \
  Kubernetes service management for this environment.
  Use 'enabled' to enable services and 'config' for service-specific options.
  
* `flake.environments.<name>.kubernetes.services.config`: \
  Service-specific configurations for this environment.
  Options are imported from flake.kubernetes.services.<name>.options.
  
* `flake.environments.<name>.kubernetes.services.config.amd-gpu-device-plugin`: [attribute set] Configuration for amd-gpu-device-plugin service
* `flake.environments.<name>.kubernetes.services.config.argocd`: [attribute set] Configuration for argocd service
* `flake.environments.<name>.kubernetes.services.config.bootstrap`: [attribute set] Configuration for bootstrap service
* `flake.environments.<name>.kubernetes.services.config.cert-manager`: [attribute set] Configuration for cert-manager service
* `flake.environments.<name>.kubernetes.services.config.cilium`: Configuration for cilium service
* `flake.environments.<name>.kubernetes.services.config.cilium-bgp`: [attribute set] Configuration for cilium-bgp service
* `flake.environments.<name>.kubernetes.services.config.cilium.devices`: [null or (list of string)] List of devices
* `flake.environments.<name>.kubernetes.services.config.cilium.directRoutingDevice`: [null or string] Default routing device
* `flake.environments.<name>.kubernetes.services.config.coredns`: Configuration for coredns service
* `flake.environments.<name>.kubernetes.services.config.coredns.clusterIP`: [string] CoreDNS ClusterIP address allocation
* `flake.environments.<name>.kubernetes.services.config.csi-driver-nfs`: Configuration for csi-driver-nfs service
* `flake.environments.<name>.kubernetes.services.config.csi-driver-nfs.volumes`: NFS volumes to create storage classes for
* `flake.environments.<name>.kubernetes.services.config.csi-driver-nfs.volumes.<name>.server`: [string] NFS server address
* `flake.environments.<name>.kubernetes.services.config.csi-driver-nfs.volumes.<name>.share`: [string] NFS share path
* `flake.environments.<name>.kubernetes.services.config.envoy-gateway`: [attribute set] Configuration for envoy-gateway service
* `flake.environments.<name>.kubernetes.services.config.gateway-api`: [attribute set] Configuration for gateway-api service
* `flake.environments.<name>.kubernetes.services.config.hubble-ui`: [attribute set] Configuration for hubble-ui service
* `flake.environments.<name>.kubernetes.services.config.romm`: [attribute set] Configuration for romm service
* `flake.environments.<name>.kubernetes.services.config.rook-ceph`: [attribute set] Configuration for rook-ceph service
* `flake.environments.<name>.kubernetes.services.config.sops-secrets-operator`: Configuration for sops-secrets-operator service
* `flake.environments.<name>.kubernetes.services.config.sops-secrets-operator.replicaCount`: [signed integer] Number of replicas for the sops-secrets-operator
* `flake.environments.<name>.kubernetes.services.config.volume-snapshots`: [attribute set] Configuration for volume-snapshots service
* `flake.environments.<name>.kubernetes.services.enabled`: [list of string] \
  List of enabled services for this environment.
  Services without configuration can be enabled by simply adding them to this list.
  
* `flake.environments.<name>.kubernetes.sso`: Single Sign-On configuration
* `flake.environments.<name>.kubernetes.sso.credentialsEnvironment`: [null or string] Environment variable name containing SSO credentials
* `flake.environments.<name>.kubernetes.sso.issuerPattern`: [null or string] \
  SSO issuer URL pattern for authentication.
  Use {clientID} as a placeholder for the client ID.
  Example: "https://idm.example.com/oauth2/openid/{clientID}"
  
* `flake.environments.<name>.kubernetes.tlsSanIps`: [list of string] Additional IPs to include in Kubernetes API server TLS certificate SANs
* `flake.environments.<name>.location`: Geographic location information
* `flake.environments.<name>.location.country`: [string] ISO country code
* `flake.environments.<name>.location.region`: [string] Geographic region or datacenter
* `flake.environments.<name>.monitoring`: Monitoring configuration including cross-environment scanning
* `flake.environments.<name>.monitoring.scanEnvironments`: [list of string] Additional environments to scan for metrics (e.g., ['dev'] for prod scanning dev)
* `flake.environments.<name>.name`: [string] Human-readable environment name
* `flake.environments.<name>.networks`: \
  Network definitions for the environment.
  Example: `{
    management = { cidr = "10.0.0.0/24"; purpose = "management"; };
    cluster = { cidr = "172.20.0.0/16"; purpose = "kubernetes-pods"; };
  }`
  
* `flake.environments.<name>.networks.<name>.assignments`: [attribute set of string] \
  Static IP address assignments within this network.
  Maps service/resource names to their assigned IP addresses.
  Example: { kube-apiserver-vip = "10.9.0.100"; }
  
* `flake.environments.<name>.networks.<name>.cidr`: [string] Network CIDR (e.g., 10.0.0.0/24)
* `flake.environments.<name>.networks.<name>.description`: [string] Human-readable description of the network
* `flake.environments.<name>.networks.<name>.ipv6_cidr`: [null or string] IPv6 network CIDR (e.g., fd64:0:1::/64)
* `flake.environments.<name>.networks.<name>.purpose`: [string] Network purpose (e.g., management, cluster, service)
* `flake.environments.<name>.secrets`: [unspecified value] \
  Secret helper functions for this environment.
  Provides: from, for, forInlineFor, forOidcService, oidcIssuerFor
  
* `flake.environments.<name>.services`: \
  Service-specific domain mappings for the environment.
  Used by OAuth2 provisioning, ingress configuration, and service discovery.
  Example: services.argocd.domain = "argocd.zeroday.run";
  
* `flake.environments.<name>.services.<name>.domain`: [null or string] \
  Override domain for this service.
  If null, defaults to <service-name>.${environment.domain}
  
* `flake.environments.<name>.tags`: [attribute set of string] Environment-wide tags for metadata and organization
* `flake.environments.<name>.timezone`: [string] Default timezone for the environment
* `flake.environments.<name>.users`: Users in this environment with their features and configuration
* `flake.environments.<name>.users.<name>.configuration`: [module] User-specific home configuration
* `flake.environments.<name>.users.<name>.features`: [list of string] \
  List of features specific to the user.
  
  While a feature may specify NixOS modules in addition to home
  modules, only home modules will affect configuration.  For this
  reason, users should be encouraged to avoid pointlessly specifying
  their own NixOS modules.
  

- `flake.environments`: [attribute set of (submodule)] Environment configurations
- `flake.environments.<name>.acme`: [null] ACME certificate authority configuration
- `flake.environments.<name>.acme.dnsProvider`: [string] DNS provider for ACME challenges
- `flake.environments.<name>.acme.dnsResolver`: [string] DNS resolver for ACME validation
- `flake.environments.<name>.acme.server`: [string] ACME server URL
- `flake.environments.<name>.delegation`: [null] Cross-environment delegation configuration
- `flake.environments.<name>.delegation.authTo`: [null or string] Environment to delegate authentication to (e.g., 'prod')
- `flake.environments.<name>.delegation.logsTo`: [null or string] Environment to delegate log shipping to (e.g., 'prod')
- `flake.environments.<name>.delegation.metricsTo`: [null or string] Environment to delegate metrics reporting to (e.g., 'prod')
- `flake.environments.<name>.dnsServers`: [list of string] DNS server IPs for the environment
- `flake.environments.<name>.domain`: [string] Base domain for the environment
- `flake.environments.<name>.email`: [null] Email configuration for the environment
- `flake.environments.<name>.email.adminEmail`: [string] Default admin email address
- `flake.environments.<name>.email.domain`: [string] Email domain (e.g., json64.dev)
- `flake.environments.<name>.gatewayIp`: [string] Gateway IP address for the environment
- `flake.environments.<name>.gatewayIpV6`: [string] Gateway IPv6 address for the environment
- `flake.environments.<name>.id`: [signed integer] ID of the environment
- `flake.environments.<name>.ipv6`: [null] IPv6 ULA and prefix configuration for NPTv6 translation
- `flake.environments.<name>.ipv6.external_prefix`: [null or string] External ISP prefix for NPTv6 translation (e.g., 2001:db8::/64)
- `flake.environments.<name>.ipv6.kubernetes_prefix`: [null or string] IPv6 prefix for Kubernetes pods (e.g., fd64:0:2::/64)
- `flake.environments.<name>.ipv6.management_prefix`: [null or string] IPv6 prefix for management network (e.g., fd64:0:1::/64)
- `flake.environments.<name>.ipv6.services_prefix`: [null or string] IPv6 prefix for Kubernetes services (e.g., fd64:0:3::/64)
- `flake.environments.<name>.ipv6.ula_prefix`: [null or string] ULA prefix for the environment (e.g., fd64::/48)
- `flake.environments.<name>.kubernetes`: [null] Kubernetes-specific network configuration
- `flake.environments.<name>.kubernetes.clusterCidr`: [string] Kubernetes pod network CIDR
- `flake.environments.<name>.kubernetes.kubeAPIVIP`: [string] Kubernetes API VIP
- `flake.environments.<name>.kubernetes.loadBalancer`: [null] LoadBalancer configuration
- `flake.environments.<name>.kubernetes.loadBalancer.cidr`: [string] IP range for LoadBalancer services
- `flake.environments.<name>.kubernetes.loadBalancer.reservations`: [attribute set of string] Reserved IP addresses for specific LoadBalancer services
- `flake.environments.<name>.kubernetes.secretsFile`: [null or absolute path] Path to sops encrypted secret file for kubernetes environment
- `flake.environments.<name>.kubernetes.serviceCidr`: [string] Kubernetes service network CIDR
- `flake.environments.<name>.kubernetes.services`: [null] Kubernetes service management for this environment.
Use 'enabled' to enable services and 'config' for service-specific options.

- `flake.environments.<name>.kubernetes.services.config`: [null] Service-specific configurations for this environment.
Options are imported from flake.kubernetes.services.<name>.options.

- `flake.environments.<name>.kubernetes.services.config.argocd`: [attribute set] Configuration for argocd service
- `flake.environments.<name>.kubernetes.services.config.bootstrap`: [attribute set] Configuration for bootstrap service
- `flake.environments.<name>.kubernetes.services.config.cert-manager`: [attribute set] Configuration for cert-manager service
- `flake.environments.<name>.kubernetes.services.config.cilium`: [null] Configuration for cilium service
- `flake.environments.<name>.kubernetes.services.config.cilium-bgp`: [attribute set] Configuration for cilium-bgp service
- `flake.environments.<name>.kubernetes.services.config.cilium.devices`: [null or (list of string)] List of devices
- `flake.environments.<name>.kubernetes.services.config.cilium.directRoutingDevice`: [null or string] Default routing device
- `flake.environments.<name>.kubernetes.services.config.envoy-gateway`: [attribute set] Configuration for envoy-gateway service
- `flake.environments.<name>.kubernetes.services.config.gateway-api`: [attribute set] Configuration for gateway-api service
- `flake.environments.<name>.kubernetes.services.config.hubble-ui`: [attribute set] Configuration for hubble-ui service
- `flake.environments.<name>.kubernetes.services.config.romm`: [attribute set] Configuration for romm service
- `flake.environments.<name>.kubernetes.services.config.sops-secrets-operator`: [null] Configuration for sops-secrets-operator service
- `flake.environments.<name>.kubernetes.services.config.sops-secrets-operator.replicaCount`: [signed integer] Number of replicas for the sops-secrets-operator
- `flake.environments.<name>.kubernetes.services.enabled`: [list of string] List of enabled services for this environment.
Services without configuration can be enabled by simply adding them to this list.

- `flake.environments.<name>.kubernetes.sso`: [null] Single Sign-On configuration
- `flake.environments.<name>.kubernetes.sso.credentialsEnvironment`: [null or string] Environment variable name containing SSO credentials
- `flake.environments.<name>.kubernetes.sso.issuerPattern`: [null or string] SSO issuer URL pattern for authentication.
Use {clientID} as a placeholder for the client ID.
Example: "https://idm.example.com/oauth2/openid/{clientID}"

- `flake.environments.<name>.kubernetes.tlsSanIps`: [list of string] Additional IPs to include in Kubernetes API server TLS certificate SANs
- `flake.environments.<name>.location`: [null] Geographic location information
- `flake.environments.<name>.location.country`: [string] ISO country code
- `flake.environments.<name>.location.region`: [string] Geographic region or datacenter
- `flake.environments.<name>.monitoring`: [null] Monitoring configuration including cross-environment scanning
- `flake.environments.<name>.monitoring.scanEnvironments`: [list of string] Additional environments to scan for metrics (e.g., ['dev'] for prod scanning dev)
- `flake.environments.<name>.name`: [string] Human-readable environment name
- `flake.environments.<name>.networks`: [attribute set of (submodule)] Network definitions for the environment.
Example: `{
  management = { cidr = "10.0.0.0/24"; purpose = "management"; };
  cluster = { cidr = "172.20.0.0/16"; purpose = "kubernetes-pods"; };
}`

- `flake.environments.<name>.networks.<name>.cidr`: [string] Network CIDR (e.g., 10.0.0.0/24)
- `flake.environments.<name>.networks.<name>.description`: [string] Human-readable description of the network
- `flake.environments.<name>.networks.<name>.ipv6_cidr`: [null or string] IPv6 network CIDR (e.g., fd64:0:1::/64)
- `flake.environments.<name>.networks.<name>.purpose`: [string] Network purpose (e.g., management, cluster, service)
- `flake.environments.<name>.tags`: [attribute set of string] Environment-wide tags for metadata and organization
- `flake.environments.<name>.timezone`: [string] Default timezone for the environment
- `flake.environments.<name>.users`: [lazy attribute set of (submodule)] Users in this environment with their features and configuration
- `flake.environments.<name>.users.<name>.configuration`: [module] User-specific home configuration
- `flake.environments.<name>.users.<name>.features`: [list of string] List of features specific to the user.

While a feature may specify NixOS modules in addition to home
modules, only home modules will affect configuration.  For this
reason, users should be encouraged to avoid pointlessly specifying
their own NixOS modules.


- `clusters`: Kubernetes cluster definitions. Each cluster references an environment and owns all k8s configuration.

- `clusters.<name>.environment`: [string] Name of the environment this cluster belongs to (references environments.<name>)

- `clusters.<name>.getAssignment`: [function that evaluates to a(n) (null or string)] Look up an IP assignment by name across all cluster networks.

- `clusters.<name>.hosts`: [null or (list of string)] \
  Explicit list of host names in this cluster.
  When null, hosts are discovered from the environment via the configured role.

- `clusters.<name>.kubernetes`: Kubernetes configuration for this cluster

- `clusters.<name>.kubernetes.services`: \
  Kubernetes service management for this environment.
  Use 'enabled' to enable services and 'config' for service-specific options.

- `clusters.<name>.kubernetes.services.config`: \
  Service-specific configurations for this environment.
  Options are imported from kubernetes.services.\<name>.options.

- `clusters.<name>.kubernetes.services.config.amd-gpu-device-plugin`: [attribute set] Configuration for amd-gpu-device-plugin service

- `clusters.<name>.kubernetes.services.config.argocd`: [attribute set] Configuration for argocd service

- `clusters.<name>.kubernetes.services.config.bootstrap`: [attribute set] Configuration for bootstrap service

- `clusters.<name>.kubernetes.services.config.cert-manager`: [attribute set] Configuration for cert-manager service

- `clusters.<name>.kubernetes.services.config.cilium`: Configuration for cilium service

- `clusters.<name>.kubernetes.services.config.cilium-bgp`: [attribute set] Configuration for cilium-bgp service

- `clusters.<name>.kubernetes.services.config.cilium.devices`: [null or (list of string)] List of devices

- `clusters.<name>.kubernetes.services.config.cilium.directRoutingDevice`: [null or string] Default routing device

- `clusters.<name>.kubernetes.services.config.coredns`: [attribute set] Configuration for coredns service

- `clusters.<name>.kubernetes.services.config.csi-driver-nfs`: Configuration for csi-driver-nfs service

- `clusters.<name>.kubernetes.services.config.csi-driver-nfs.volumes`: NFS volumes to create storage classes for

- `clusters.<name>.kubernetes.services.config.csi-driver-nfs.volumes.<name>.server`: [string] NFS server address

- `clusters.<name>.kubernetes.services.config.csi-driver-nfs.volumes.<name>.share`: [string] NFS share path

- `clusters.<name>.kubernetes.services.config.envoy-gateway`: [attribute set] Configuration for envoy-gateway service

- `clusters.<name>.kubernetes.services.config.gateway-api`: [attribute set] Configuration for gateway-api service

- `clusters.<name>.kubernetes.services.config.hubble-ui`: [attribute set] Configuration for hubble-ui service

- `clusters.<name>.kubernetes.services.config.longhorn`: [attribute set] Configuration for longhorn service

- `clusters.<name>.kubernetes.services.config.romm`: [attribute set] Configuration for romm service

- `clusters.<name>.kubernetes.services.config.rook-ceph`: [attribute set] Configuration for rook-ceph service

- `clusters.<name>.kubernetes.services.config.sops-secrets-operator`: Configuration for sops-secrets-operator service

- `clusters.<name>.kubernetes.services.config.sops-secrets-operator.replicaCount`: [signed integer] Number of replicas for the sops-secrets-operator

- `clusters.<name>.kubernetes.services.config.volume-snapshots`: [attribute set] Configuration for volume-snapshots service

- `clusters.<name>.kubernetes.services.enabled`: [list of string] \
  List of enabled services for this environment.
  Services without configuration can be enabled by simply adding them to this list.

- `clusters.<name>.kubernetes.sso`: Single Sign-On configuration

- `clusters.<name>.kubernetes.sso.credentialsEnvironment`: [null or string] Environment variable name containing SSO credentials

- `clusters.<name>.kubernetes.sso.issuerPattern`: [null or string] \
  SSO issuer URL pattern for authentication.
  Use {clientID} as a placeholder for the client ID.
  Example: "https://idm.example.com/oauth2/openid/{clientID}"

- `clusters.<name>.kubernetes.tlsSanIps`: [list of string] Additional IPs to include in Kubernetes API server TLS certificate SANs

- `clusters.<name>.name`: [string] Cluster name

- `clusters.<name>.networks`: \
  Cluster network definitions (pods, services, loadbalancers).
  These are cluster-scoped networks separate from the environment's infrastructure networks.

- `clusters.<name>.networks.<name>.assignments`: [attribute set of string] Static IP address assignments within this network.

- `clusters.<name>.networks.<name>.cidr`: [string] Network CIDR (e.g., 172.20.0.0/16)

- `clusters.<name>.networks.<name>.description`: [string] Human-readable description of the network

- `clusters.<name>.networks.<name>.dnsServers`: [list of string] DNS server IPs for this network

- `clusters.<name>.networks.<name>.gatewayIp`: [null or string] Gateway IP address for this network

- `clusters.<name>.networks.<name>.gatewayIpV6`: [null or string] Gateway IPv6 address for this network

- `clusters.<name>.networks.<name>.ipv6_cidr`: [null or string] IPv6 network CIDR

- `clusters.<name>.resolvedEnvironment`: [unspecified value] Resolved environment configuration from environments.<environment>

- `clusters.<name>.resolvedHosts`: [attribute set of unspecified value] Resolved host configurations for this cluster (from explicit hosts or role-based discovery)

- `clusters.<name>.role`: [string] Host role for auto-discovery. Hosts in the cluster's environment with this role are included.

- `clusters.<name>.secretPath`: [absolute path] Path to the directory containing secrets for this cluster.

- `clusters.<name>.secrets`: [unspecified value] Secret helper functions for this cluster

- `clusters.<name>.sopsAgeRecipient`: [null or string] SOPS age public key for encrypting secrets destined for this cluster's sops-secrets-operator. Auto-derived from secretPath/k3s-sops-age-key.pub.
